# common arguments for mysql binaries
mysql_flags="-u root --socket=/tmp/mysql.sock"
admin_flags="$mysql_flags"


function usage() {
  [ $# == 2 ] && echo "error: $1"
  cat /usr/share/container-layer/mysql/usage/*.txt 2>/dev/null | envsubst
  exit 1
}

function validate_variables() {
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
    echo "Waiting for MySQL to start ..."
    sleep 1
  done
}

function start_local_mysql() {
  # Now start mysqld and add appropriate users.
  echo 'Starting local mysqld server ...'
  ${MYSQL_PREFIX}/libexec/mysqld \
    --skip-networking --socket=/tmp/mysql.sock "$@" &
  mysql_pid=$!
  wait_for_mysql $mysql_pid
}

# Initialize the MySQL database (create user accounts and the initial database)
function start_with_initialize_database() {
  if [ -d "$MYSQL_DATADIR/mysql" ]; then
    start_local_mysql
    return
  fi

  echo 'Running mysql_install_db ...'
  mysql_install_db --rpm --datadir=$MYSQL_DATADIR
  start_local_mysql "$@"

  [ -v MYSQL_DISABLE_CREATE_DB ] && return

  # ignore error (test db does not exists)
  mysqladmin $admin_flags -f drop test || :
  mysqladmin $admin_flags create "${MYSQL_DATABASE}"

mysql $mysql_flags <<EOSQL
    CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
    FLUSH PRIVILEGES ;
EOSQL

  if [ -v MYSQL_ROOT_PASSWORD ]; then
mysql $mysql_flags <<EOSQL
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
EOSQL
  fi

  cont_source_hooks post-init mysql
}


