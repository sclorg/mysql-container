function validate_replication_variables() {
  if ! [[ -v MYSQL_DATABASE && -v MYSQL_SOURCE_USER && -v MYSQL_SOURCE_PASSWORD && \
        ( "${MYSQL_RUNNING_AS_REPLICA:-0}" != "1" || -v MYSQL_SOURCE_SERVICE_NAME ) ]]; then
    echo
    echo "For source/replica replication, you have to specify following environment variables:"
    echo "  MYSQL_SOURCE_SERVICE_NAME (replica only)"
    echo "  MYSQL_DATABASE"
    echo "  MYSQL_SOURCE_USER"
    echo "  MYSQL_SOURCE_PASSWORD"
    echo
    return 1
  fi
  [[ "$MYSQL_DATABASE" =~ $mysql_identifier_regex ]] || usage "Invalid database name"
  [[ "$MYSQL_SOURCE_USER"     =~ $mysql_identifier_regex ]] || usage "Invalid MySQL source username"
  [ ${#MYSQL_SOURCE_USER} -le 16 ] || usage "MySQL source username too long (maximum 16 characters)"
  [[ "$MYSQL_SOURCE_PASSWORD" =~ $mysql_password_regex   ]] || usage "Invalid MySQL source password"
}

if [ -v MYSQL_RUNNING_AS_SOURCE ] || [ -v MYSQL_RUNNING_AS_REPLICA ] ; then
  validate_replication_variables
fi
