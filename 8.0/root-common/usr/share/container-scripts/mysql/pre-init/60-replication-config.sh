# mysqld configuration for replication scenarios

if [ -v MYSQL_RUNNING_AS_MASTER ] || [ -v MYSQL_RUNNING_AS_SLAVE ] ; then
  log_info 'Processing basic MySQL configuration for replication (master and slave) files ...'
  envsubst < ${CONTAINER_SCRIPTS_PATH}/pre-init/my-repl-gtid.cnf.template > /etc/my.cnf.d/repl-gtid.cnf
fi

if [ -v MYSQL_RUNNING_AS_MASTER ] ; then
  log_info 'Processing basic MySQL configuration for replication (master only) files ...'
  envsubst < ${CONTAINER_SCRIPTS_PATH}/pre-init/my-master.cnf.template > /etc/my.cnf.d/master.cnf
fi

if [ -v MYSQL_RUNNING_AS_SLAVE ] ; then
  log_info 'Processing basic MySQL configuration for replication (slave only) files ...'
  envsubst < ${CONTAINER_SCRIPTS_PATH}/pre-init/my-slave.cnf.template > /etc/my.cnf.d/slave.cnf
fi

