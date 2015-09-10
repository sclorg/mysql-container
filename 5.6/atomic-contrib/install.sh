#!/bin/sh

MYSQL_UID=27
MYSQL_GID=27

ARGS="$@"

# find user option in arguments
while [ -n "$1" ] ; do
  case "$1" in
  -u=*)
    MYSQL_UID=${1:3}
  ;;
  --user=*)
    MYSQL_UID=${1:7}
    break
  ;;
  -u|--user)
    MYSQL_UID="$2"
    break
  ;;
  esac
  shift
done

# now we can either have X or X:X in MYSQL_UID, so act according ':' presence
if ! [[ "$MYSQL_UID" == *":"* ]] ; then
  CHMOD_ARG="$MYSQL_UID:$MYSQL_GID"
else
  CHMOD_ARG="$MYSQL_UID"
fi


# init datadir in case it doesn't exist yet
if ! [ -d "${DATADIR}" ] ; then
  mkdir -p "${DATADIR}"
  chown -R "${CHMOD_ARG}" "${DATADIR}"
  chmod -R 770 "${DATADIR}"
fi

docker create --restart=on-failure:5 -v "${DATADIR}:/var/lib/mysql/data:Z" --name "${NAME}" "$ARGS" "${IMAGE}"

