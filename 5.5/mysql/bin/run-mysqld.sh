#!/bin/bash -e

function usage {
	echo "You must specify following environment variables:"
	echo "  \$MYSQL_USER"
	echo "  \$MYSQL_PASSWORD"
	echo "  \$MYSQL_DATABASE"
	exit 1
}

test -z "$MYSQL_USER" && usage
test -z "$MYSQL_PASSWORD" && usage
test -z "$MYSQL_DATABASE" && usage

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9-_!@#$%^&*()_+{}|:<>?=' | fold -w 12 | head -n 1)}

if [ ! -d '/var/lib/mysql/data' ]; then

	echo 'Running mysql_install_db ...'
	scl enable mysql55 "mysql_install_db --user=mysql --datadir=/var/lib/mysql/data"
	echo 'Finished mysql_install_db'
	chown -R mysql:mysql /var/lib/mysql

	# These statements _must_ be on individual lines, and _must_ end with
	# semicolons (no line breaks or comments are permitted).
	# TODO proper SQL escaping on ALL the things D:
	TEMP_FILE='/tmp/mysql-first-time.sql'
	cat > "$TEMP_FILE" <<-EOSQL
		DELETE FROM mysql.user ;
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` ;
		CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}' ;
		GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
		FLUSH PRIVILEGES ;
	EOSQL

	set -- "$@" --init-file="$TEMP_FILE"
fi

# SCL in CentOS/RHEL 7 doesn't support --exec, we need to do it ourselves
export X_SCLS="mysql55"
source /opt/rh/mysql55/enable

exec /opt/rh/mysql55/root/usr/libexec/mysqld --defaults-file=/opt/openshift/etc/my.cnf "$@" 2>&1
