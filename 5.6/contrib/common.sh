#!/bin/bash

# Data directory where MySQL database files live. The data subdirectory is here
# because .bashrc and my.cnf both live in /var/lib/mysql/ and we don't want a
# volume to override it.
export MYSQL_DATADIR=/var/lib/mysql/data

# Configuration settings.
export MYSQL_DEFAULTS_FILE=$HOME/my.cnf
export MYSQL_LOWER_CASE_TABLE_NAMES=${MYSQL_LOWER_CASE_TABLE_NAMES:-0}
export MYSQL_MAX_CONNECTIONS=${MYSQL_MAX_CONNECTIONS:-151}
export MYSQL_FT_MIN_WORD_LEN=${MYSQL_FT_MIN_WORD_LEN:-4}
export MYSQL_FT_MAX_WORD_LEN=${MYSQL_FT_MAX_WORD_LEN:-20}
export MYSQL_AIO=${MYSQL_AIO:-1}

# Be paranoid and stricter than we should be.
# https://dev.mysql.com/doc/refman/5.6/en/identifiers.html
mysql_identifier_regex='^[a-zA-Z0-9_]+$'
mysql_password_regex='^[a-zA-Z0-9_~!@#$%^&*()-=<>,.?;:|]+$'

function usage() {
  [ $# == 2 ] && echo "error: $1"
  echo "You must specify following environment variables:"
  echo "  MYSQL_USER (regex: '$mysql_identifier_regex')"
  echo "  MYSQL_PASSWORD (regex: '$mysql_password_regex')"
  echo "  MYSQL_DATABASE (regex: '$mysql_identifier_regex')"
  echo "Optional:"
  echo "  MYSQL_ROOT_PASSWORD (regex: '$mysql_password_regex')"
  echo "Settings:"
  echo "  MYSQL_LOWER_CASE_TABLE_NAMES (default: 0)"
  echo "  MYSQL_MAX_CONNECTIONS (default: 151)"
  echo "  MYSQL_FT_MIN_WORD_LEN (default: 4)"
  echo "  MYSQL_FT_MAX_WORD_LEN (default: 20)"
  echo "  MYSQL_AIO (default: 1)"
  exit 1
}

function validate_variables() {
  if ! [[ -v MYSQL_USER && -v MYSQL_PASSWORD && -v MYSQL_DATABASE ]]; then
    usage
  fi

  [[ "$MYSQL_USER"     =~ $mysql_identifier_regex ]] || usage "Invalid MySQL username"
  [ ${#MYSQL_USER} -le 16 ] || usage "MySQL username too long (maximum 16 characters)"
  [[ "$MYSQL_PASSWORD" =~ $mysql_password_regex   ]] || usage "Invalid password"
  [[ "$MYSQL_DATABASE" =~ $mysql_identifier_regex ]] || usage "Invalid database name"
  [ ${#MYSQL_DATABASE} -le 64 ] || usage "Database name too long (maximum 64 characters)"
  if [ -v MYSQL_ROOT_PASSWORD ]; then
    [[ "$MYSQL_ROOT_PASSWORD" =~ $mysql_password_regex ]] || usage "Invalid root password"
  fi
}

# Make sure env variables don't propagate to mysqld process.
function unset_env_vars() {
  unset MYSQL_USER MYSQL_PASSWORD MYSQL_DATABASE MYSQL_ROOT_PASSWORD
}

# Poll until MySQL responds to our ping.
function wait_for_mysql() {
  pid=$1 ; shift

  while [ true ]; do
    if [ -d "/proc/$pid" ]; then
      mysqladmin --socket=/tmp/mysql.sock ping &>/dev/null && return 0
    else
      return 1
    fi
    echo "Waiting for MySQL to start ..."
    sleep 1
  done
}

function start_local_mysql() {
  # Now start mysqld and add appropriate users.
  echo 'Starting local mysqld server ...'
  /opt/rh/rh-mysql56/root/usr/libexec/mysqld \
    --defaults-file=$MYSQL_DEFAULTS_FILE \
    --skip-networking --socket=/tmp/mysql.sock &
  mysql_pid=$!
  wait_for_mysql $mysql_pid
}

# Initialize the MySQL database (create user accounts and the initial database)
function initialize_database() {
  echo 'Running mysql_install_db ...'
  # Using --rpm since we need mysql_install_db behaves as in RPM
  mysql_install_db --rpm --datadir=$MYSQL_DATADIR
  start_local_mysql

  [ -v MYSQL_DISABLE_CREATE_DB ] && return

  mysqladmin $admin_flags create "${MYSQL_DATABASE}"

mysql $mysql_flags <<EOSQL
    CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
    FLUSH PRIVILEGES ;
EOSQL

  if [ -v MYSQL_ROOT_PASSWORD ]; then
mysql $mysql_flags <<EOSQL
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
EOSQL
  fi
}

# The 'server_id' number for slave needs to be within 1-4294967295 range.
# This function will take the 'hostname' if the container, hash it and turn it
# into the number.
# See: https://dev.mysql.com/doc/refman/5.6/en/replication-options.html#option_mysqld_server-id
function server_id() {
  checksum=$(sha256sum <<< $(hostname -i))
  checksum=${checksum:0:14}
  echo -n $((0x${checksum}%4294967295))
}

function wait_for_mysql_master() {
  local master_addr=""
  while [ true ]; do
    master_addr=$(mysql_master_addr)
    [ ! -z "${master_addr}" ] && break
    echo "Waiting for MySQL master service ..."
    sleep 1
  done
  echo "Got MySQL master service address: ${master_addr}"
  while [ true ]; do
    mysqladmin --host=${master_addr} --user="${MYSQL_MASTER_USER}" \
      --password="${MYSQL_MASTER_PASSWORD}" ping &>/dev/null && return 0
    echo "Waiting for MySQL master (${master_addr}) to accept connections ..."
    sleep 1
  done
}

# mysql_master_addr lookups the 'mysql-master' DNS and get list of the available
# endpoints. Each endpoint is a MySQL container with the 'master' MySQL running.
function mysql_master_addr() {
  local service_name=${MYSQL_MASTER_SERVICE_NAME:-mysql-master}
  local endpoints=$(dig ${service_name} A +search +short 2>/dev/null)
  # FIXME: This is for debugging (docker run)
  if [ -v MYSQL_MASTER_IP ]; then
    endpoints=${MYSQL_MASTER_IP-}
  fi
  echo -n "$(echo $endpoints | cut -d ' ' -f 1)"
}

function validate_replication_variables() {
  if ! [[ -v MYSQL_MASTER_USER && -v MYSQL_MASTER_PASSWORD  ]]; then
    echo
    echo "For master/slave replication, you have to specify following environment variables:"
    echo "  MYSQL_MASTER_USER"
    echo "  MYSQL_MASTER_PASSWORD"
    echo
  fi
  [[ "$MYSQL_MASTER_USER"     =~ $mysql_identifier_regex ]] || usage "Invalid MySQL master username"
  [ ${#MYSQL_MASTER_USER} -le 16 ] || usage "MySQL master username too long (maximum 16 characters)"
  [[ "$MYSQL_MASTER_PASSWORD" =~ $mysql_password_regex   ]] || usage "Invalid MySQL master password"
}
