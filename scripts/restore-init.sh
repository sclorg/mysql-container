#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

RESPALDO_A_RESTAURAR=$1

#copia de seguridad base de datos
# SUB_DIR="$(date +"%Y%m%d%H%M")"
# "SUB_DIR="$(date +"%M%H%d%m%Y")_cierre"

# rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR -R
# mkdir -p /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR
# mkdir -p backup_db_local/$SUB_DIR

# mysqldump -h${MYSQL_HOST_LOCAL} -uroot -p${MYSQL_ROOT_PASSWORD} --events ${MYSQL_DATABASE} --opt --routines --add-drop-database --table --complete-insert --create-options --master-data | gzip > backup_db_local/$SUB_DIR/${MYSQL_DATABASE}.sql.gz

if [ -f "/var/lib/mysql/data/bitacora.txt" ]; them

   export RESPALDO_A_RESTAURAR=$(cat /var/lib/mysql/data/bitacora.txt | tail -1 | awk '{print $4}')

   gunzip < ${RESPALDO_A_RESTAURAR} | mysql -uroot -hlocalhost -p${MYSQL_PASSWORD}

fi
#chown emilio:emilio backup_db_local/ -R


# tar -czvf /home/emilio/Volume_backup/$SUB_DIR/wp-content.tar.gz /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/



# gosu root tar -czvf /home/emilio/Volume_backup/$SUB_DIR/var_lib_mysql.tar.gz /var/lib/mysql


# gosu root chown emilio:emilio /home/emilio/Volume_backup -R

# rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/*cierre.cierre.php

# echo -n "<?php\n// Silence is golden." > /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/$SUB_DIR.cierre.php
