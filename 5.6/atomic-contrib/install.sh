#!/bin/sh

. /usr/share/container-layer/mysql/atomic/variables.sh

# Create directories on host from spc
mkdir -p "${HOST}/${data_dir}"
# Not supported for now: mkdir -p "${HOST}/${config_dir}"
# Not supported for now: mkdir -p "${HOST}/${log_dir}"
chcon -Rt svirt_sandbox_file_t "${HOST}/${data_dir}"
chown -R mysql.mysql "${HOST}/${data_dir}"
chmod -R 770 "${HOST}/${data_dir}"

# create container on host
chroot "${HOST}" /usr/bin/docker create -v "${data_dir}:/var/lib/mysql/data:Z" --name "${NAME}" ${OPT2} "${IMAGE}" ${OPT3}

# Create and enable systemd unit file for the service
sed -e "s/TEMPLATE/${NAME}/g" /usr/share/container-layer/mysql/atomic/template.service > "${HOST}/etc/systemd/system/${service_name}.service"
chroot "${HOST}" /usr/bin/systemctl enable "/etc/systemd/system/${service_name}.service"

