#!/bin/sh

MYSQL_UID=27
MYSQL_GID=27

mkdir -p "${DATADIR}"
chcon -Rt svirt_sandbox_file_t "${DATADIR}"
chown -R ${MYSQL_UID}.${MYSQL_GID} "${DATADIR}"
chmod -R 770 "${DATADIR}"
docker create --restart=on-failure:5 -v "${DATADIR}:/var/lib/mysql/data:Z" --name "${NAME}" "$@" "${IMAGE}"

