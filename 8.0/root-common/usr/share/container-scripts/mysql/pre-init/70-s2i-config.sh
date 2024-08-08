# additional arbitrary mysqld configuration provided by user using s2i

log_info 'Processing additional arbitrary  MySQL configuration provided by s2i ...'

process_extending_config_files ${APP_DATA}/mysql-cfg/ ${CONTAINER_SCRIPTS_PATH}/cnf/

