#!/bin/bash

source ${CONTAINER_SCRIPTS_PATH}/helpers.sh

# Data directory where MySQL database files live. The data subdirectory is here
# because .bashrc and my.cnf both live in /var/lib/mysql/ and we don't want a
# volume to override it.
export MYSQL_DATADIR=/var/lib/mysql/data

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
  export MYSQL_DATADIR_ACTION=${MYSQL_DATADIR_ACTION:-upgrade-warn}
}

# this stores whether the database was initialized from empty datadir
export MYSQL_DATADIR_FIRST_INIT=false

# Be paranoid and stricter than we should be.
# https://dev.mysql.com/doc/refman/en/identifiers.html
mysql_identifier_regex='^[a-zA-Z0-9_]+$'
mysql_password_regex='^[a-zA-Z0-9_~!@#$%^&*()-=<>,.?;:|]+$'

# Variables that are used to connect to local mysql during initialization
mysql_flags="-u root --socket=/tmp/mysql.sock"
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

# Start local MySQL server with a defaults file
function start_local_mysql() {
  log_info 'Starting MySQL server with disabled networking ...'
  ${MYSQL_PREFIX}/libexec/mysqld \
    --defaults-file=$MYSQL_DEFAULTS_FILE \
    --skip-networking --socket=/tmp/mysql.sock "$@" &
  mysql_pid=$!
  wait_for_mysql $mysql_pid
}

# Shutdown mysql flushing privileges
function shutdown_local_mysql() {
  log_info 'Shutting down MySQL ...'
  mysqladmin $admin_flags flush-privileges shutdown
}

# Initialize the MySQL database (create user accounts and the initial database)
function initialize_database() {
  log_info 'Initializing database ...'
  if [[ "$MYSQL_VERSION" < "5.7" ]] ; then
    # Using --rpm since we need mysql_install_db behaves as in RPM
    log_and_run mysql_install_db --rpm --datadir=$MYSQL_DATADIR
  else
    log_and_run ${MYSQL_PREFIX}/libexec/mysqld --initialize-insecure --datadir=$MYSQL_DATADIR --ignore-db-dir=lost+found
  fi
  start_local_mysql "$@"

  # Running mysql_upgrade creates the mysql_upgrade_info file in the data dir,
  # which is necessary to detect which version of the mysqld daemon created the data.
  # Checking empty file should not take longer than a second and one extra check should not harm.
  mysql_upgrade ${admin_flags}

  if [ -v MYSQL_RUNNING_AS_SLAVE ]; then
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
    if [ -v MYSQL_USER ]; then
      log_info "Granting privileges to user ${MYSQL_USER} for ${MYSQL_DATABASE} ..."
mysql $mysql_flags <<EOSQL
      GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
      FLUSH PRIVILEGES ;
EOSQL
    fi
  fi

  if [ -v MYSQL_ROOT_PASSWORD ]; then
    log_info "Setting password for MySQL root user ..."
    # for 5.6 and lower we use the trick that GRANT creates a user if not exists
    # because IF NOT EXISTS clause does not exist in that versions yet
    if [[ "$MYSQL_VERSION" > "5.6" ]] ; then
      mysql $mysql_flags <<EOSQL
        CREATE USER IF NOT EXISTS 'root'@'%';
EOSQL
    fi
mysql $mysql_flags <<EOSQL
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
EOSQL
  fi
  log_info 'Initialization finished'

  # remember that the database was just initialized, it may be needed on other places
  export MYSQL_DATADIR_FIRST_INIT=true
}

# The 'server_id' number for slave needs to be within 1-4294967295 range.
# This function will take the 'hostname' if the container, hash it and turn it
# into the number.
# See: https://dev.mysql.com/doc/refman/en/replication-options.html#option_mysqld_server-id
function server_id() {
  checksum=$(sha256sum <<< $(hostname -i))
  checksum=${checksum:0:14}
  echo -n $((0x${checksum}%4294967295))
}

function wait_for_mysql_master() {
  while true; do
    log_info "Waiting for MySQL master (${MYSQL_MASTER_SERVICE_NAME}) to accept connections ..."
    mysqladmin --host=${MYSQL_MASTER_SERVICE_NAME} --user="${MYSQL_MASTER_USER}" \
      --password="${MYSQL_MASTER_PASSWORD}" ping &>/dev/null && log_info "MySQL master is ready" && return 0
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

# Returns version from the daemon in integer format
function mysqld_compat_version() {
  version2number $(mysqld_version)
}

# Returns version from the datadir in the integer format
function get_datadir_version() {
  local datadir="$1"
  local upgrade_info_file=$(get_mysql_upgrade_info_file "$datadir")
  [ -r "$upgrade_info_file" ] || return
  local version_text=$(cat "$upgrade_info_file" | head -n 1)
  version2number "${version_text}"
}

# Returns name of the file in the datadir that holds version information about the data
function get_mysql_upgrade_info_file() {
  local datadir="$1"
  echo "$datadir/mysql_upgrade_info"
}

# Writes version string of the daemon into mysql_upgrade_info file
# (should be only used when the file is missing and only during limited time;
# once most deployments include this version file, we should leave it on
# scripts to generate the file right after initialization or when upgrading)
function write_mysql_upgrade_info_file() {
  local datadir="$1"
  local version=$(mysqld_version)
  local upgrade_info_file=$(get_mysql_upgrade_info_file "$datadir")
  if [ -f "$datadir/mysql_upgrade_info" ] ; then
    echo "File ${upgrade_info_file} exists, nothing is done."
  else
    log_info "Storing version '${version}' information into the data dir '${upgrade_info_file}'"
    echo "${version}" > "${upgrade_info_file}"
    mysqld_version >"$datadir/mysql_upgrade_info"
  fi
}
