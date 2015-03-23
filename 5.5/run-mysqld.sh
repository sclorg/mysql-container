#!/bin/bash

# For SCL enablement
source $HOME/.bashrc

set -eu

# Data directory where MySQL database files live. The data subdirectory is here
# because .bashrc lives in /var/lib/mysql/ and we don't want a volume to
# override it.
MYSQL_DATADIR=/var/lib/mysql/data
MYSQL_DEFAULTS_FILE=/opt/openshift/etc/my.cnf

# Be paranoid and stricter than we should be.
# https://dev.mysql.com/doc/refman/5.5/en/identifiers.html
mysql_identifier_regex='^[a-zA-Z0-9_]+$'
mysql_password_regex='^[a-zA-Z0-9_~!@#$%^&*()-=<>,.?;:|]+$'

function usage() {
	if [ $# == 2 ]; then
		echo "error: $1"
	fi
	echo "You must specify following environment variables:"
	echo "  \$MYSQL_USER (regex: '$mysql_identifier_regex')"
	echo "  \$MYSQL_PASSWORD (regex: '$mysql_password_regex')"
	echo "  \$MYSQL_DATABASE (regex: '$mysql_identifier_regex')"
	echo "Optional:"
	echo "  \$MYSQL_ROOT_PASSWORD (regex: '$mysql_password_regex')"
	exit 1
}

function check_env_vars() {
	if ! [[ -v MYSQL_USER && -v MYSQL_PASSWORD && -v MYSQL_DATABASE ]]; then
		usage
	fi

	[[ "$MYSQL_USER"     =~ $mysql_identifier_regex ]] || usage "Invalid MySQL username"
	[ ${#MYSQL_USER} -le 16 ] || usage "MySQL username too long (maximum 16 characters)"
	[[ "$MYSQL_PASSWORD" =~ $mysql_password_regex   ]] || usage "Invalid password"
	[[ "$MYSQL_DATABASE" =~ $mysql_identifier_regex ]] || usage "Invalid database name"
	[ ${#MYSQL_DATABASE} -le 64 ] || usage "Database name too long (maximum 64 characters)"
	if [ -v MYSQL_ROOT_PASSWORD ]; then
		[[ "$MYSQL_ROOT_PASSWORD" =~ $mysql_password_regex ]] || usage "Invalid root password"
	fi
}

# Make sure env variables don't propagate to mysqld process.
function unset_env_vars() {
	unset MYSQL_USER MYSQL_PASSWORD MYSQL_DATABASE MYSQL_ROOT_PASSWORD
}

# Poll until MySQL responds to our ping.
function wait_for_mysql() {
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

function initialize_database() {
	check_env_vars

	echo 'Running mysql_install_db'
	mysql_install_db --datadir=$MYSQL_DATADIR

	# Now start mysqld and add appropriate users.
	echo 'Starting mysqld to create users'
	/opt/rh/mysql55/root/usr/libexec/mysqld \
		--defaults-file=$MYSQL_DEFAULTS_FILE \
		--skip-networking --socket=/tmp/mysql.sock &
	mysql_pid=$!
	wait_for_mysql $mysql_pid

	# Set common flags.
	mysql_flags="-u root --socket=/tmp/mysql.sock"
	admin_flags="--defaults-file=$MYSQL_DEFAULTS_FILE $mysql_flags"

	mysqladmin $admin_flags -f drop test
	mysqladmin $admin_flags create "${MYSQL_DATABASE}"
	mysql $mysql_flags <<-EOSQL
		CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
		GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
		FLUSH PRIVILEGES ;
	EOSQL

	if [ -v MYSQL_ROOT_PASSWORD ]; then
		mysql $mysql_flags <<-EOSQL
			GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
		EOSQL
	fi
	mysqladmin $admin_flags flush-privileges shutdown
}

if [ "$1" = "mysqld" ]; then

	shift

	if [ ! -d "$MYSQL_DATADIR/mysql" ]; then
		initialize_database
	fi

	unset_env_vars

	exec /opt/rh/mysql55/root/usr/libexec/mysqld \
		--defaults-file=$MYSQL_DEFAULTS_FILE \
		"$@" 2>&1
fi

unset_env_vars
exec "$@"
