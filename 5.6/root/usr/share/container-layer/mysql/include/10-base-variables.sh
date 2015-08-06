# Data directory where MySQL database files live. The data subdirectory is here
# because .bashrc and my.cnf both live in /var/lib/mysql/ and we don't want a
# volume to override it.
export MYSQL_DATADIR=/var/lib/mysql/data

# Configuration settings.
export MYSQL_DEFAULTS_FILE=$HOME/my.cnf

# Get prefix rather than hard-code it
export MYSQL_PREFIX=$(which mysqld_safe|sed -e 's|/bin/mysqld_safe$||')

# Set default project for container library
export CONT_PROJECT="mysql"

# Be paranoid and stricter than we should be.
# https://dev.mysql.com/doc/refman/5.5/en/identifiers.html
export mysql_identifier_regex='^[a-zA-Z0-9_]+$'
export mysql_password_regex='^[a-zA-Z0-9_~!@#$%^&*()-=<>,.?;:|]+$'
