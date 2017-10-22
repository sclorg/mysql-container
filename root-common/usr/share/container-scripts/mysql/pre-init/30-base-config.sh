log_info 'Processing basic MySQL configuration files ...'
envsubst < ${CONTAINER_SCRIPTS_PATH}/pre-init/my-base.cnf.template > /etc/my.cnf.d/base.cnf

