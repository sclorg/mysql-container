#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


#copia de seguridad base de datos
# SUB_DIR="$(date +"%Y%m%d%H%M")"
# "SUB_DIR="$(date +"%M%H%d%m%Y")_cierre"

# rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR -R
# mkdir -p /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR
# mkdir -p backup_db_local/$SUB_DIR

# mysqldump -h${MYSQL_HOST_LOCAL} -uroot -p${MYSQL_ROOT_PASSWORD} --events ${MYSQL_DATABASE} --opt --routines --add-drop-database --table --complete-insert --create-options --master-data | gzip > backup_db_local/$SUB_DIR/${MYSQL_DATABASE}.sql.gz

# mysqldump -hlocalhost -uroot -p${MYSQL_ROOT_PASSWORD} --create-options --add-drop-database --add-drop-table --all-databases --opt --routines --complete-insert | gzip > /var/lib/mysql/backup/$(date +"%Y%m%d%H%M").sql.gz &&  echo "Respaldo realizado exitosamente $(date +"%Y%m%d%H%M")" >> /var/lib/mysql/backup/bitacora.txt
#chown emilio:emilio backup_db_local/ -R

mysqldump -hlocalhost -u${MYSQL_USER} -p${MYSQL_PASSWORD} --create-options --add-drop-database --add-drop-table  --databases ${MYSQL_DATABASE} --opt --routines --complete-insert | gzip > /var/lib/mysql/data/$(date +"%Y%m%d%H%M").sql.gz &&  echo "Respaldo realizado exitosamente $(date +"%Y%m%d%H%M").sql.gz" >> /var/lib/mysql/data/bitacora.txt




# tar -czvf /home/emilio/Volume_backup/$SUB_DIR/wp-content.tar.gz /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/



# gosu root tar -czvf /home/emilio/Volume_backup/$SUB_DIR/var_lib_mysql.tar.gz /var/lib/mysql


# gosu root chown emilio:emilio /home/emilio/Volume_backup -R

# rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/*cierre.cierre.php

# echo -n "<?php\n// Silence is golden." > /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/$SUB_DIR.cierre.php

