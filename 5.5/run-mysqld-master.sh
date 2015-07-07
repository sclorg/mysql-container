#!/bin/bash
#
# This is an entrypoint that runs the MySQL server in the 'master' mode.
#
source ${HOME}/common.sh

set -eu

mysql_flags="-u root --socket=/tmp/mysql.sock"
admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

validate_replication_variables
validate_variables

# Generate the unique 'server-id' for this master
export MYSQL_SERVER_ID=$(server_id)
echo "The 'master' server-id is ${MYSQL_SERVER_ID}"

# Process the MySQL configuration files
envsubst < $HOME/my.cnf.template > $HOME/my-common.cnf
envsubst < $HOME/my-master.cnf.template > $MYSQL_DEFAULTS_FILE

# Initialize MySQL database
initialize_database

# Setup the 'master' replication on the MySQL server
mysql $mysql_flags <<EOSQL
  GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_MASTER_USER}'@'%' IDENTIFIED BY '${MYSQL_MASTER_PASSWORD}';
  FLUSH PRIVILEGES;
EOSQL

# Restart the MySQL server with public IP bindings
mysqladmin $admin_flags flush-privileges shutdown
unset_env_vars
exec /opt/rh/mysql55/root/usr/libexec/mysqld --defaults-file=$MYSQL_DEFAULTS_FILE "$@" 2>&1
