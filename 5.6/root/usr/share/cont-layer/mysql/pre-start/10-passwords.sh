
# Set the password for MySQL user and root everytime this container is started.
# This allows to change the password by editing the deployment configuration.
mysql $mysql_flags <<EOSQL
  SET PASSWORD FOR '${MYSQL_USER}'@'%' = PASSWORD('${MYSQL_PASSWORD}');
EOSQL

# The MYSQL_ROOT_PASSWORD is optional
if [ -v MYSQL_ROOT_PASSWORD ]; then
mysql $mysql_flags <<EOSQL
    SET PASSWORD FOR 'root'@'%' = PASSWORD('${MYSQL_ROOT_PASSWORD}');
EOSQL
fi

