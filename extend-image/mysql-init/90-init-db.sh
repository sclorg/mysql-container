init_arbitrary_database() {

    export RESPALDO_A_RESTAURAR=$(cat /var/lib/mysql/data/bitacora.txt | tail -1 | awk '{print $4}')

    gunzip < ${RESPALDO_A_RESTAURAR} | mysql -uroot -hlocalhost -p${MYSQL_PASSWORD}
    }

if ! [ -v MYSQL_RUNNING_AS_MASTER ] && $MYSQL_DATADIR_FIRST_INIT && [ -f "/var/lib/mysql/data/bitacora.txt" ]; then
  init_arbitrary_database
fi
