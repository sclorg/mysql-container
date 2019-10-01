password_change() {
  log_info 'Setting passwords ...'

  # Set the password for MySQL user and root everytime this container is started.
  # This allows to change the password by editing the deployment configuration.
  if [[ -v MYSQL_USER && -v MYSQL_PASSWORD ]]; then
    TMP_FILE=$(mktemp /tmp/mysql_userXXXXX)
mysql $mysql_flags >> $TMP_FILE <<EOSQL
      SELECT user FROM mysql.user;
EOSQL
    grep -Fxq "$MYSQL_USER" "$TMP_FILE" > /dev/null
    RETCODE=$?
    if [[ $RETCODE -eq 0 ]]; then
  mysql $mysql_flags <<EOSQL
        ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
EOSQL
    else
      log_info "User ${MYSQL_USER} does not exist in database."
    fi
    rm "${TMP_FILE}"
    unset TMP_FILE

  fi

  # The MYSQL_ROOT_PASSWORD is optional, therefore we need to either enable remote
  # access with a password if the variable is set or disable remote access otherwise.
  if [ -v MYSQL_ROOT_PASSWORD ]; then
mysql $mysql_flags <<EOSQL
      CREATE USER IF NOT EXISTS 'root'@'%';
      ALTER USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
      GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
EOSQL
  else
mysql $mysql_flags <<EOSQL
      DROP USER IF EXISTS 'root'@'%';
      FLUSH PRIVILEGES;
EOSQL
  fi
}

if ! [ -v MYSQL_RUNNING_AS_SLAVE ] ; then
  password_change
fi

unset -f password_change
