#!/bin/bash
#
# This is an entrypoint that runs the MySQL server in the 'slave' mode.
#
source ${HOME}/common.sh

set -eu

mysql_flags="-u root --socket=/tmp/mysql.sock"
admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

validate_replication_variables

# Generate the unique 'server-id' for this master
export MYSQL_SERVER_ID=$(server_id)
echo "The 'slave' server-id is ${MYSQL_SERVER_ID}"

# Process the MySQL configuration files
envsubst < $HOME/my.cnf.template > $HOME/my-common.cnf
envsubst < $HOME/my-slave.cnf.template > $MYSQL_DEFAULTS_FILE

# Initialize MySQL database and wait for the MySQL master to accept connections
# This will also disable the database and user creation (the data will be
# fetched from the 'master' server).
export MYSQL_DISABLE_CREATE_DB=1
initialize_database
wait_for_mysql_master

# Get binlog file and position from master
STATUS_INFO=$(mysql --host "$(mysql_master_addr)" "-u${MYSQL_MASTER_USER}" "-p${MYSQL_MASTER_PASSWORD}" -e 'SHOW MASTER STATUS\G')
BINLOG_POSITION=$(echo "$STATUS_INFO" | grep 'Position:' | head -n 1 | sed -e 's/^\s*Position: //')
BINLOG_FILE=$(echo "$STATUS_INFO" | grep 'File:' | head -n 1 | sed -e 's/^\s*File: //')

if [ -z "${BINLOG_FILE}" -o -z "${BINLOG_POSITION}" ] ; then
  echo "Could not read binlog position or file from master"
  exit 1
fi

mysql $mysql_flags <<EOSQL
  CHANGE MASTER TO MASTER_HOST='$(mysql_master_addr)',MASTER_USER='${MYSQL_MASTER_USER}', MASTER_PASSWORD='${MYSQL_MASTER_PASSWORD}', MASTER_LOG_FILE='${BINLOG_FILE}', MASTER_LOG_POS=${BINLOG_POSITION};
  SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1; SLAVE START;
EOSQL

# Restart the MySQL server with public IP bindings
mysqladmin $admin_flags flush-privileges shutdown
unset_env_vars
exec /opt/rh/mysql55/root/usr/libexec/mysqld --defaults-file=$MYSQL_DEFAULTS_FILE \
  --report-host=$(hostname -i) "$@" 2>&1
