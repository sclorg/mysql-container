# The 'server_id' number for slave needs to be within 1-4294967295 range.
# This function will take the 'hostname' if the container, hash it and turn it
# into the number.
# See: https://dev.mysql.com/doc/refman/5.5/en/replication-options.html#option_mysqld_server-id
function server_id() {
  checksum=$(sha256sum <<< $(hostname -i))
  checksum=${checksum:0:14}
  echo -n $((0x${checksum}%4294967295))
}

function wait_for_mysql_master() {
  local master_addr=""
  while [ true ]; do
    master_addr=$(mysql_master_addr)
    [ ! -z "${master_addr}" ] && break
    echo "Waiting for MySQL master service ..."
    sleep 1
  done
  echo "Got MySQL master service address: ${master_addr}"
  while [ true ]; do
    mysqladmin --host=${master_addr} --user="${MYSQL_MASTER_USER}" \
      --password="${MYSQL_MASTER_PASSWORD}" ping &>/dev/null && return 0
    echo "Waiting for MySQL master (${master_addr}) to accept connections ..."
    sleep 1
  done
}

# mysql_master_addr lookups the 'mysql-master' DNS and get list of the available
# endpoints. Each endpoint is a MySQL container with the 'master' MySQL running.
function mysql_master_addr() {
  local service_name=${MYSQL_MASTER_SERVICE_NAME:-mysql-master}
  local endpoints=$(dig ${service_name} A +search +short 2>/dev/null)
  # FIXME: This is for debugging (docker run)
  if [ -v MYSQL_MASTER_IP ]; then
    endpoints=${MYSQL_MASTER_IP-}
  fi
  echo -n "$(echo $endpoints | cut -d ' ' -f 1)"
}

function validate_replication_variables() {
  if ! [[ -v MYSQL_MASTER_USER && -v MYSQL_MASTER_PASSWORD  ]]; then
    echo
    echo "For master/slave replication, you have to specify following environment variables:"
    echo "  MYSQL_MASTER_USER"
    echo "  MYSQL_MASTER_PASSWORD"
    echo
    exit 1
  fi
  [[ "$MYSQL_MASTER_USER"     =~ $mysql_identifier_regex ]] || usage "Invalid MySQL master username"
  [ ${#MYSQL_MASTER_USER} -le 16 ] || usage "MySQL master username too long (maximum 16 characters)"
  [[ "$MYSQL_MASTER_PASSWORD" =~ $mysql_password_regex   ]] || usage "Invalid MySQL master password"
}

