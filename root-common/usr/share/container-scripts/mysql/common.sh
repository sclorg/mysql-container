#!/bin/bash

source ${CONTAINER_SCRIPTS_PATH}/helpers.sh

# Data directory where MySQL database files live. The data subdirectory is here
# because .bashrc and my.cnf both live in /var/lib/mysql/ and we don't want a
# volume to override it.
export MYSQL_DATADIR=/var/lib/mysql/data

# Unix local domain socket to connect to MySQL server
export MYSQL_LOCAL_SOCKET=/tmp/mysql.sock

# Configuration settings.
export MYSQL_DEFAULTS_FILE=${MYSQL_DEFAULTS_FILE:-/etc/my.cnf}

function export_setting_variables() {
  export MYSQL_BINLOG_FORMAT=${MYSQL_BINLOG_FORMAT:-STATEMENT}
  export MYSQL_LOWER_CASE_TABLE_NAMES=${MYSQL_LOWER_CASE_TABLE_NAMES:-0}
  export MYSQL_LOG_QUERIES_ENABLED=${MYSQL_LOG_QUERIES_ENABLED:-0}
  export MYSQL_MAX_CONNECTIONS=${MYSQL_MAX_CONNECTIONS:-151}
  export MYSQL_FT_MIN_WORD_LEN=${MYSQL_FT_MIN_WORD_LEN:-4}
  export MYSQL_FT_MAX_WORD_LEN=${MYSQL_FT_MAX_WORD_LEN:-20}
  export MYSQL_AIO=${MYSQL_AIO:-1}
  export MYSQL_MAX_ALLOWED_PACKET=${MYSQL_MAX_ALLOWED_PACKET:-200M}
  export MYSQL_TABLE_OPEN_CACHE=${MYSQL_TABLE_OPEN_CACHE:-400}
  export MYSQL_SORT_BUFFER_SIZE=${MYSQL_SORT_BUFFER_SIZE:-256K}

  # Export memory limit variables and calculate limits
  local export_vars=$(cgroup-limits) && export $export_vars || exit 1
  if [ -n "${NO_MEMORY_LIMIT:-}" -o -z "${MEMORY_LIMIT_IN_BYTES:-}" ]; then
    export MYSQL_KEY_BUFFER_SIZE=${MYSQL_KEY_BUFFER_SIZE:-32M}
    export MYSQL_READ_BUFFER_SIZE=${MYSQL_READ_BUFFER_SIZE:-8M}
    export MYSQL_INNODB_BUFFER_POOL_SIZE=${MYSQL_INNODB_BUFFER_POOL_SIZE:-32M}
    export MYSQL_INNODB_LOG_FILE_SIZE=${MYSQL_INNODB_LOG_FILE_SIZE:-8M}
    export MYSQL_INNODB_LOG_BUFFER_SIZE=${MYSQL_INNODB_LOG_BUFFER_SIZE:-8M}
  else
    export MYSQL_KEY_BUFFER_SIZE=${MYSQL_KEY_BUFFER_SIZE:-$((MEMORY_LIMIT_IN_BYTES/1024/1024/10))M}
    export MYSQL_READ_BUFFER_SIZE=${MYSQL_READ_BUFFER_SIZE:-$((MEMORY_LIMIT_IN_BYTES/1024/1024/20))M}
    export MYSQL_INNODB_BUFFER_POOL_SIZE=${MYSQL_INNODB_BUFFER_POOL_SIZE:-$((MEMORY_LIMIT_IN_BYTES/1024/1024/2))M}
    # We are multiplying by 15 first and dividing by 100 later so we get as much
    # precision as possible with whole numbers. Result is 15% of memory.
    export MYSQL_INNODB_LOG_FILE_SIZE=${MYSQL_INNODB_LOG_FILE_SIZE:-$((MEMORY_LIMIT_IN_BYTES*15/1024/1024/100))M}
    export MYSQL_INNODB_LOG_BUFFER_SIZE=${MYSQL_INNODB_LOG_BUFFER_SIZE:-$((MEMORY_LIMIT_IN_BYTES*15/1024/1024/100))M}
  fi
  export MYSQL_DATADIR_ACTION=${MYSQL_DATADIR_ACTION:-}
  export MYSQL_DEFAULT_AUTHENTICATION_PLUGIN=${MYSQL_DEFAULT_AUTHENTICATION_PLUGIN:-caching_sha2_password}
  export MYSQL_AUTHENTICATION_POLICY=${MYSQL_AUTHENTICATION_POLICY:-$MYSQL_DEFAULT_AUTHENTICATION_PLUGIN,,}

  # keep old names working for compatibility
  MYSQL_MASTER_SERVICE_NAME=${MYSQL_MASTER_SERVICE_NAME:-}
  MYSQL_MASTER_USER=${MYSQL_MASTER_USER:-}
  MYSQL_MASTER_PASSWORD=${MYSQL_MASTER_PASSWORD:-}
  export MYSQL_SOURCE_SERVICE_NAME=${MYSQL_SOURCE_SERVICE_NAME:-$MYSQL_MASTER_SERVICE_NAME}
  export MYSQL_SOURCE_USER=${MYSQL_SOURCE_USER:-MYSQL_MASTER_USER}
  export MYSQL_SOURCE_PASSWORD=${MYSQL_SOURCE_PASSWORD:-MYSQL_MASTER_PASSWORD}
}

# this stores whether the database was initialized from empty datadir
export MYSQL_DATADIR_FIRST_INIT=false

# Be paranoid and stricter than we should be.
# https://dev.mysql.com/doc/refman/en/identifiers.html
mysql_identifier_regex='^[a-zA-Z0-9_]+$'
mysql_password_regex='^[a-zA-Z0-9_~!@#$%^&*()-=<>,.?;:|]+$'

# Variables that are used to connect to local mysql during initialization
mysql_flags="-u root --socket=$MYSQL_LOCAL_SOCKET"
admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

# Make sure env variables don't propagate to mysqld process.
function unset_env_vars() {
  log_info 'Cleaning up environment variables MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE and MYSQL_ROOT_PASSWORD ...'
  unset MYSQL_USER MYSQL_PASSWORD MYSQL_DATABASE MYSQL_ROOT_PASSWORD
}

# Poll until MySQL responds to our ping.
function wait_for_mysql() {
  pid=$1 ; shift

  while true; do
    if [ -d "/proc/$pid" ]; then
      mysqladmin $admin_flags ping &>/dev/null && log_info "MySQL started successfully" && return 0
    else
      return 1
    fi
    log_info "Waiting for MySQL to start ..."
    sleep 1
  done
}

function wait_for_mysql_shutdown() {
  while pgrep -f "${MYSQL_PREFIX}/libexec/mysqld" >/dev/null; do
    log_info "Waiting for MySQL to shutdown ..."
    sleep 1
  done
}

# Start local MySQL server with a defaults file
function start_local_mysql() {
  log_info 'Starting MySQL server with disabled networking ...'
  ${MYSQL_PREFIX}/libexec/mysqld \
    --defaults-file=$MYSQL_DEFAULTS_FILE \
    --skip-networking --socket=$MYSQL_LOCAL_SOCKET "$@" &
  mysql_pid=$!
  wait_for_mysql $mysql_pid
}

# Shutdown mysql flushing privileges
function shutdown_local_mysql() {
  log_info 'Shutting down MySQL ...'
  mysqladmin $admin_flags flush-privileges shutdown
  wait_for_mysql_shutdown
}

# Initialize the MySQL database (create user accounts and the initial database)
function initialize_database() {
  log_info 'Initializing database ...'
  if [ "`version2number $MYSQL_VERSION`" -lt '800' ] ; then
    log_initialization ${MYSQL_PREFIX}/libexec/mysqld --initialize --datadir=$MYSQL_DATADIR --ignore-db-dir=lost+found
  else
    log_initialization ${MYSQL_PREFIX}/libexec/mysqld --initialize --datadir=$MYSQL_DATADIR
  fi

  # The '--initialize' option sets an auto generated root password.
  mysql_flags="$mysql_flags -p${AUTOGENERATED_ROOT_PASSWORD}"
  admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

  start_local_mysql "$@"

  # The first valid connection after running 'mysql --initialize' must use
  # the --connect-expired-password option and set a new root password.
  mysql_flags="$mysql_flags --connect-expired-password"
  admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

  # As we have a temporary auto generated root password, the first thing to do is to
  # change it. We try first to set it to an empty password, but if this is not allowed
  # (due to validate_plugin, for example), we then set it to MYSQL_ROOT_PASSWORD.
  if [ -v MYSQL_ROOT_PASSWORD ]; then
    log_info "Setting password for MySQL root user ..."
    set +e
    mysql $mysql_flags -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"
    RETCODE=$?
    set -e

    if [ $RETCODE -eq 0 ]; then
      mysql_flags="-u root --socket=$MYSQL_LOCAL_SOCKET"
    else
      mysql $mysql_flags -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
      mysql_flags="-u root --socket=$MYSQL_LOCAL_SOCKET -p${MYSQL_ROOT_PASSWORD}"
    fi

    mysql $mysql_flags <<EOSQL
      CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
      GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
EOSQL
  else
    mysql $mysql_flags -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''";
    mysql_flags="-u root --socket=$MYSQL_LOCAL_SOCKET"
  fi
  admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

  # Running mysql_upgrade no longer needed, mysql_upgrade is effectively NOOP
  # and all necessary data files transformation are done automatically.
  # mysql_upgrade ${admin_flags}

  if [ -v MYSQL_RUNNING_AS_REPLICA ]; then
    log_info 'Initialization finished'
    return 0
  fi

  # Do not care what option is compulsory here, just create what is specified
  if [ -v MYSQL_USER ]; then
    log_info "Creating user specified by MYSQL_USER (${MYSQL_USER}) ..."
mysql $mysql_flags <<EOSQL
    CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
EOSQL
  fi

  if [ -v MYSQL_DATABASE ]; then
    log_info "Creating database ${MYSQL_DATABASE} ..."
    mysqladmin $admin_flags create "${MYSQL_DATABASE}"
    if [ -v MYSQL_CHARSET ]; then
        log_info "Changing character set to ${MYSQL_CHARSET} ..."
mysql $mysql_flags <<EOSQL
      ALTER DATABASE \`${MYSQL_DATABASE}\` CHARACTER SET \`${MYSQL_CHARSET}\` ;
EOSQL
    fi
    if [ -v MYSQL_COLLATION ]; then
        log_info "Changing collation to ${MYSQL_COLLATION} ..."
mysql $mysql_flags <<EOSQL
      ALTER DATABASE \`${MYSQL_DATABASE}\` COLLATE \`${MYSQL_COLLATION}\` ;
EOSQL
    fi

    if [ -v MYSQL_USER ]; then
      log_info "Granting privileges to user ${MYSQL_USER} for ${MYSQL_DATABASE} ..."
mysql $mysql_flags <<EOSQL
      GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
      FLUSH PRIVILEGES ;
EOSQL
    fi
  fi

  log_info 'Initialization finished'

  # remember that the database was just initialized, it may be needed on other places
  export MYSQL_DATADIR_FIRST_INIT=true
}

# The 'server_id' number for replica needs to be within 1-4294967295 range.
# This function will take the 'hostname' if the container, hash it and turn it
# into the number.
# See: https://dev.mysql.com/doc/refman/en/replication-options.html#option_mysqld_server-id
function server_id() {
  checksum=$(sha256sum <<< $(hostname -I))
  checksum=${checksum:0:14}
  echo -n $((0x${checksum}%4294967295))
}

function wait_for_mysql_source() {
  while true; do
    log_info "Waiting for MySQL source (${MYSQL_SOURCE_SERVICE_NAME}) to accept connections ..."
    mysqladmin --host=${MYSQL_SOURCE_SERVICE_NAME} --user="${MYSQL_SOURCE_USER}" \
      --password="${MYSQL_SOURCE_PASSWORD}" ping &>/dev/null && log_info "MySQL source is ready" && return 0
    sleep 1
  done
}

# get_matched_files finds file for image extending
function get_matched_files() {
  local custom_dir default_dir
  custom_dir="$1"
  default_dir="$2"
  files_matched="$3"
  find "$default_dir" -maxdepth 1 -type f -name "$files_matched" -printf "%f\n"
  [ -d "$custom_dir" ] && find "$custom_dir" -maxdepth 1 -type f -name "$files_matched" -printf "%f\n"
}

# process_extending_files process extending files in $1 and $2 directories
# - source all *.sh files
#   (if there are files with same name source only file from $1)
function process_extending_files() {
  local custom_dir default_dir
  custom_dir=$1
  default_dir=$2

  while read filename ; do
    echo "=> sourcing $filename ..."
    # Custom file is prefered
    if [ -f $custom_dir/$filename ]; then
      source $custom_dir/$filename
    else
      source $default_dir/$filename
    fi
  done <<<"$(get_matched_files "$custom_dir" "$default_dir" '*.sh' | sort -u)"
}

# process extending config files in $1 and $2 directories
# - expand variables in *.cnf and copy the files into /etc/my.cnf.d directory
#   (if there are files with same name source only file from $1)
function process_extending_config_files() {
  local custom_dir default_dir
  custom_dir=$1
  default_dir=$2

  while read filename ; do
    echo "=> sourcing $filename ..."
    # Custom file is prefered
    if [ -f $custom_dir/$filename ]; then
       envsubst < $custom_dir/$filename > /etc/my.cnf.d/$filename
    else
       envsubst < $default_dir/$filename > /etc/my.cnf.d/$filename
    fi
  done <<<"$(get_matched_files "$custom_dir" "$default_dir" '*.cnf' | sort -u)"
}

# Converts string version to the integer format (5.5.33 is converted to 505,
# 10.1.23-MariaDB is converted into 1001, etc.
function version2number() {
  local version_major=$(echo "$1" | grep -o -e '^[0-9]*\.[0-9]*')
  printf %d%02d ${version_major%%.*} ${version_major##*.}
}

# Converts the version in format of an integer into major.minor
function number2version() {
  local numver=${1}
  echo $((numver / 100)).$((numver % 100))
}

# Prints version of the mysqld that is currently available (string)
function mysqld_version() {
  ${MYSQL_PREFIX}/libexec/mysqld -V | awk '{print $3}'
}

# Checks if mysql server is allowing connection for 'root'@'localhost' without password
function is_allowing_connection_with_empty_password() {
  set +e
  mysql -u root --socket=$MYSQL_LOCAL_SOCKET -e "DO 0;" # NO-OP command, just to test the connection
  RETCODE=$?
  set -e
  return $RETCODE
}
