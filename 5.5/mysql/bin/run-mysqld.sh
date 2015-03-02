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

if [ ! -d '/var/lib/mysql' ]; then

	echo 'Running mysql_install_db ...'
	scl enable mysql55 "mysql_install_db --user=mysql --datadir=/var/lib/mysql"
	echo 'Finished mysql_install_db'

	# These statements _must_ be on individual lines, and _must_ end with
	# semicolons (no line breaks or comments are permitted).
	# TODO proper SQL escaping on ALL the things D:
	TEMP_FILE='/tmp/mysql-first-time.sql'
	cat > "$TEMP_FILE" <<-EOSQL
		DELETE FROM mysql.user ;
		CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}' ;
		GRANT ALL ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` ;
		FLUSH PRIVILEGES ;
	EOSQL

	set -- "$@" --init-file="$TEMP_FILE"
fi

chown -R mysql:mysql /var/lib/mysql

# SCL in CentOS/RHEL 7 doesn't support --exec, we need to do it ourselves
export X_SCLS="mysql55"
source /opt/rh/mysql55/enable

exec /opt/rh/mysql55/root/usr/libexec/mysqld --defaults-file=/opt/openshift/etc/my.cnf "$@" 2>&1
