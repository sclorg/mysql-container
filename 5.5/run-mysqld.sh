#!/bin/bash

source $HOME/common.sh
set -eu

mysql_flags="-u root --socket=/tmp/mysql.sock"
admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

if [ "$1" == "mysqld-master" ] &&  [ ! -d "${MYSQL_DATADIR}/mysql" ]; then
  shift
  exec /usr/local/bin/run-mysqld-master.sh $@
fi

if [ "$1" == "mysqld-slave" ] &&  [ ! -d "${MYSQL_DATADIR}/mysql" ]; then
  shift
  exec /usr/local/bin/run-mysqld-slave.sh $@
fi

if [ "$1" == "mysqld" ]; then
  validate_variables
  envsubst < ${MYSQL_DEFAULTS_FILE}.template > $MYSQL_DEFAULTS_FILE

  if [ ! -d "$MYSQL_DATADIR/mysql" ]; then
    initialize_database
    mysqladmin $admin_flags flush-privileges shutdown
  fi

  shift
  unset_env_vars
  exec /opt/rh/mysql55/root/usr/libexec/mysqld --defaults-file=$MYSQL_DEFAULTS_FILE "$@" 2>&1
fi

unset_env_vars
exec "$@"
