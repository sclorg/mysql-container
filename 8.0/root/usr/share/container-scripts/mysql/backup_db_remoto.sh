#!/bin/bash -x

source ./../la29db.env

# NOMBRE_BD=$1
# NOMBRE_USUARIO_BD=$2
# PASSWORD_USUARIO_BD=$3
# NOMBRE_SITIO_FTP=$4




#copia de seguridad base de datos
SUB_DIR="$(date +"%Y%m%d%H%M")"
# "SUB_DIR="$(date +"%M%H%d%m%Y")_cierre"

#rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR -R
#mkdir -p /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR
mkdir -p ./../remoto/DataBase_backup_remoto/$SUB_DIR

mysqldump -h${MYSQL_HOST_REMOTO} -u${MYSQL_USER} -p${MYSQL_PASSWORD} --events ${MYSQL_DATABASE} | gzip > ./../remoto/DataBase_backup_remoto/$SUB_DIR/${MYSQL_DATABASE}.sql.gz


# tar -czvf /home/emilio/Volume_backup/$SUB_DIR/wp-content.tar.gz /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/



# gosu root tar -czvf /home/emilio/Volume_backup/$SUB_DIR/var_lib_mysql.tar.gz /var/lib/mysql


# gosu root chown emilio:emilio /home/emilio/Volume_backup -R

# rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/*cierre.cierre.php

# echo -n "<?php\n// Silence is golden." > /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/$SUB_DIR.cierre.php

