# mysqld configuration for replication scenarios

if [ -v MYSQL_RUNNING_AS_SOURCE ] || [ -v MYSQL_RUNNING_AS_REPLICA ] ; then
  log_info 'Processing basic MySQL configuration for replication (source and replica) files ...'
  envsubst < ${CONTAINER_SCRIPTS_PATH}/pre-init/my-repl-gtid.cnf.template > /etc/my.cnf.d/repl-gtid.cnf
fi

if [ -v MYSQL_RUNNING_AS_SOURCE ] ; then
  log_info 'Processing basic MySQL configuration for replication (source only) files ...'
  envsubst < ${CONTAINER_SCRIPTS_PATH}/pre-init/my-source.cnf.template > /etc/my.cnf.d/source.cnf
fi

if [ -v MYSQL_RUNNING_AS_REPLICA ] ; then
  log_info 'Processing basic MySQL configuration for replication (replica only) files ...'
  envsubst < ${CONTAINER_SCRIPTS_PATH}/pre-init/my-replica.cnf.template > /etc/my.cnf.d/replica.cnf
fi

