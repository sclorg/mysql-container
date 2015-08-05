#!/bin/bash

set -eux

TIME_SEC=1000
TIME_MIN=$((60 * $TIME_SEC))
HOST_DOCKER_IP=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')
OPENSHIFT_CONFIG_DIR="/tmp/openshift-config"
OPENSHIFT_NODE_CONFIG="node-`hostname`/node-config.yaml"

# time_now return the time since the epoch in millis
function time_now()
{
  echo $(date +%s000)
}

# wait_for_url_timed attempts to access a url in order to
# determine if it is available to service requests.
#
# $1 - The URL to check
# $2 - Optional prefix to use when echoing a successful result
# $3 - Optional maximum time to wait before giving up (Default: 10s)
function wait_for_url_timed {
  STARTTIME=$(date +%s)
  url=$1
  prefix=${2:-}
  max_wait=${3:-10*TIME_SEC}
  wait=0.2
  expire=$(($(time_now) + $max_wait))
  set +e
  while [[ $(time_now) -lt $expire ]]; do
    out=$(curl -k --max-time 2 -fs $url 2>/dev/null)
    if [ $? -eq 0 ]; then
      set -e
      echo ${prefix}${out}
      ENDTIME=$(date +%s)
      echo "[INFO] Success accessing '$url' after $(($ENDTIME - $STARTTIME)) seconds"
      return 0
    fi
    sleep $wait
  done
  echo "ERROR: gave up waiting for $url"
  set -e
  return 1
}

function setup_dns() {
  # Make ourselves the default resolver. This is needes so FQDNs such as
  # "pod-name.namespace.svc.cluster.local" can be resolved.
  if ! grep -q $HOST_DOCKER_IP /etc/resolv.conf; then
    sudo sed -i "1inameserver $HOST_DOCKER_IP" /etc/resolv.conf
  fi

  cat /etc/resolv.conf

  sudo rm -rf $OPENSHIFT_CONFIG_DIR
  # Generate openshift config file and edit the node config with DNS pointing to us.
  docker run --rm -i --privileged --net=host \
    -v $OPENSHIFT_CONFIG_DIR:/config \
    openshift/origin start --write-config=/config
  sudo sed -i "s/dnsIP: .*/dnsIP: $HOST_DOCKER_IP/" $OPENSHIFT_CONFIG_DIR/$OPENSHIFT_NODE_CONFIG
}

# Start openshift. We're using local generated config file that has DNS updated.
function start_openshift() {
  docker run -d --name "openshift-origin" \
    --privileged --net=host \
    -v /:/rootfs:ro -v /var/run:/var/run:rw -v /sys:/sys:ro -v /var/lib/docker:/var/lib/docker:rw \
    -v $OPENSHIFT_CONFIG_DIR:/var/lib/openshift/openshift.local.config \
    -v /var/lib/openshift/openshift.local.volumes:/var/lib/openshift/openshift.local.volumes \
    openshift/origin start \
      --master-config=/var/lib/openshift/openshift.local.config/master/master-config.yaml \
      --node-config=/var/lib/openshift/openshift.local.config/$OPENSHIFT_NODE_CONFIG \
      --loglevel=5
}

function dump_logs() {
  docker logs openshift-origin
}

#
# Helper functions to run commands inside of the OpenShift Docker container.
#
function run() {
  docker exec openshift-origin /bin/bash -c "$@"
}

function run_interactive() {
  docker exec -i openshift-origin /bin/bash -c "$@"
}


# Main
setup_dns
start_openshift
# FIXME
yum -y install nfs-utils
set +x
echo "Waiting for OpenShift to start ..."
wait_for_url_timed "https://${HOST_DOCKER_IP}:8443/healthz" "" 90*TIME_SEC >/dev/null
set -x

# Install mysql command line tool so we can make test queries.
run "yum -y install mysql"

# Create new project.
run "oc new-project replication"

# Allow all pods to run as privileged, so NFS server works.
# FIXME: There doesn't seem to be a nice way to simply add a new user to an SCC
run "oc patch scc privileged -p '{\"users\":[\"system:serviceaccount:openshift-infra:build-controller\",\"system:serviceaccount:replication:default\"]}'"

# Create Persistent Volumes backed by NFS.
cat examples/replica/nfs-pv-provider.json | run_interactive "oc process -f - | oc create -f -"

# Now create MySQL replica scenario.
cat examples/replica/mysql_replica.json | run_interactive "oc process -f - | oc create -f -"

# Wait until master and slave are up.
#set +x
echo "Waiting for MySQL Master and Replica to come online"
trap dump_logs ERR
wait_for_url_timed "mysql-master.replication.svc.cluster.local:3306" "" 5*TIME_MIN >/dev/null
wait_for_url_timed "mysql-slave.replication.svc.cluster.local:3306" "" 1*TIME_MIN >/dev/null
set -x

# Get environment variables from master, so we know the passwords.
export $(run "oc env --list dc mysql-master | grep -v '^#'")

#
# Tests start here.
#

# Create table in master.
run_interactive "mysql -h mysql-master.replication.svc.cluster.local -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}" <<EOF
CREATE TABLE tbl (col1 VARCHAR(20), col2 VARCHAR(20));
INSERT INTO tbl VALUES ('foo1', 'bar1');
EOF

sleep 2

# FIXME: Should log in as normal user, doesn't work right now.
# Verify that values are replicated in slave.
SLAVE_POD_NAME=$(run "oc get pods | grep mysql-slave | cut -f 1 -d ' '" | head -n 1)
run "oc exec $SLAVE_POD_NAME -- /bin/bash -c 'mysql -uroot ${MYSQL_DATABASE} -e \"SELECT * FROM tbl;\"'" | grep -q foo1

echo "All tests finished successfully"
