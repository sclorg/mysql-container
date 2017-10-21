# Set the password for MySQL user and root everytime this container is started.
# This allows to change the password by editing the deployment configuration.
if [[ -v MYSQL_USER && -v MYSQL_PASSWORD ]]; then
  mysql $mysql_flags <<EOSQL
    SET PASSWORD FOR '${MYSQL_USER}'@'%' = PASSWORD('${MYSQL_PASSWORD}');
EOSQL
fi

# The MYSQL_ROOT_PASSWORD is optional, therefore we need to either enable remote
# access with a password if the variable is set or disable remote access otherwise.
if [ -v MYSQL_ROOT_PASSWORD ]; then
  # create a user if it doesn't exist and set its password
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
else
  if [[ "$MYSQL_VERSION" < "5.7" ]] ; then
    mysql $mysql_flags <<EOSQL
      GRANT USAGE ON *.* TO 'root'@'%';
      DROP USER 'root'@'%';
      FLUSH PRIVILEGES;
EOSQL
  else
    mysql $mysql_flags <<EOSQL
      DROP USER IF EXISTS 'root'@'%';
      FLUSH PRIVILEGES;
EOSQL
  fi
fi

