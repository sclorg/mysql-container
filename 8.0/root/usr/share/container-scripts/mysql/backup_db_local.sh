#!/bin/bash -x

source docker/mdb/mariadb.env

# NOMBRE_BD=$1
# NOMBRE_USUARIO_BD=$2
# PASSWORD_USUARIO_BD=$3
# NOMBRE_SITIO_FTP=$4




#copia de seguridad base de datos
SUB_DIR="$(date +"%Y%m%d%H%M")"
# "SUB_DIR="$(date +"%M%H%d%m%Y")_cierre"

#rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR -R
#mkdir -p /home/emilio/ftp/$NOMBRE_SITIO_FTP/backup/cierre/$SUB_DIR
mkdir -p backup_db_local/$SUB_DIR

# mysqldump -h${MYSQL_HOST_LOCAL} -uroot -p${MYSQL_ROOT_PASSWORD} --events ${MYSQL_DATABASE} --opt --routines --add-drop-database --table --complete-insert --create-options --master-data | gzip > backup_db_local/$SUB_DIR/${MYSQL_DATABASE}.sql.gz

docker exec -it la29wordpress_mdb_1 bash -c 'mysqldump -h192.168.0.2 -uroot -ppla --events c93db1' > backup_db_local/$SUB_DIR/c93db1.sql


#chown emilio:emilio backup_db_local/ -R


# tar -czvf /home/emilio/Volume_backup/$SUB_DIR/wp-content.tar.gz /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/



# gosu root tar -czvf /home/emilio/Volume_backup/$SUB_DIR/var_lib_mysql.tar.gz /var/lib/mysql


# gosu root chown emilio:emilio /home/emilio/Volume_backup -R

# rm -f /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/*cierre.cierre.php

# echo -n "<?php\n// Silence is golden." > /home/emilio/ftp/$NOMBRE_SITIO_FTP/web/wp-content/$SUB_DIR.cierre.php

