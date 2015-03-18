#!/bin/bash -e

# Be paranoid and stricter than we should be.
# https://dev.mysql.com/doc/refman/5.5/en/identifiers.html
mysql_identifier_regex='^[a-zA-Z0-9_]+$'
mysql_password_regex='^[a-zA-Z0-9_~!@#$%^&*()-=<>,.?;:|]+$'

function usage {
	echo "You must specify following environment variables:"
	echo "  \$MYSQL_USER (regex: '$mysql_identifier_regex')"
	echo "  \$MYSQL_PASSWORD (regex: '$mysql_password_regex')"
	echo "  \$MYSQL_DATABASE (regex: '$mysql_identifier_regex')"
	echo "Optional:"
	echo "  \$MYSQL_ROOT_PASSWORD (regex: '$mysql_password_regex')"
	exit 1
}

function valid_mysql_identifier {
	local var="$1" ; shift
	[[ "${var}" =~ $mysql_identifier_regex ]]
}

function valid_mysql_password {
	local var="$1" ; shift
	[[ "${var}" =~ $mysql_password_regex ]]
}

valid_mysql_identifier "$MYSQL_USER"     || usage
valid_mysql_password   "$MYSQL_PASSWORD" || usage
valid_mysql_identifier "$MYSQL_DATABASE" || usage

# Make sure env variables don't propagate to mysqld process.
mysql_user="$MYSQL_USER" ; unset MYSQL_USER
mysql_pass="$MYSQL_PASSWORD" ; unset MYSQL_PASSWORD
mysql_db="$MYSQL_DATABASE" ; unset MYSQL_DATABASE

# Root password.
if [ "$MYSQL_ROOT_PASSWORD" ]; then
	valid_mysql_password "$MYSQL_ROOT_PASSWORD" || usage
	root_pass="$MYSQL_ROOT_PASSWORD"
fi
unset MYSQL_ROOT_PASSWORD

# SCL in CentOS/RHEL 7 doesn't support --exec, we need to do it ourselves
# The '|| exit 1' is here so -e doesn't propagate into scl_source.
source scl_source enable mysql55 || exit 1

# Poll until MySQL responds to our ping.
function wait_for_mysql {
	pid=$1 ; shift

	while [ true ]; do
		if [ -d "/proc/$pid" ]; then
			mysqladmin --socket=/tmp/mysql.sock ping &>/dev/null && return 0
		else
			return 1
		fi
		echo "Waiting for MySQL to start"
		sleep 1
	done
}

if [ ! -d '/var/lib/mysql/mysql' ]; then

	echo 'Running mysql_install_db'
	mysql_install_db --user=mysql --datadir=/var/lib/mysql
	# TODO: Not needed with --user=mysql. However, we should
	#       strive to make this script runnable without root privileges
	#chown -R mysql:mysql /var/lib/mysql

	# Now start mysqld and add appropriate users.
	echo 'Starting mysqld to create users'
	/opt/rh/mysql55/root/usr/libexec/mysqld \
		--defaults-file=/opt/openshift/etc/my.cnf \
		--skip-networking --socket=/tmp/mysql.sock &
	mysql_pid=$!
	wait_for_mysql $mysql_pid

	mysqladmin --socket=/tmp/mysql.sock -f drop test
	mysqladmin --socket=/tmp/mysql.sock create "${mysql_db}"
	mysql --socket=/tmp/mysql.sock <<-EOSQL
		CREATE USER '${mysql_user}'@'%' IDENTIFIED BY '${mysql_pass}';
		GRANT ALL ON \`${mysql_db}\`.* TO '${mysql_user}'@'%' ;
		FLUSH PRIVILEGES ;
	EOSQL

	if [ -v root_pass ]; then
		mysql --socket=/tmp/mysql.sock <<-EOSQL
			GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${root_pass}';
		EOSQL
	fi
	mysqladmin --socket=/tmp/mysql.sock flush-privileges shutdown
fi

exec /opt/rh/mysql55/root/usr/libexec/mysqld \
	--defaults-file=/opt/openshift/etc/my.cnf \
	"$@" 2>&1
