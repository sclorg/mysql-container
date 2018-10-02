FROM centos/s2i-core-centos7

# MySQL image for OpenShift.
#
# Volumes:
#  * /var/lib/mysql/data - Datastore for MySQL
# Environment:
#  * $MYSQL_USER - Database user name
#  * $MYSQL_PASSWORD - User's password
#  * $MYSQL_DATABASE - Name of the database to create
#  * $MYSQL_ROOT_PASSWORD (Optional) - Password for the 'root' MySQL account

ENV MYSQL_VERSION=8.0 \
    APP_DATA=/opt/app-root/src \
    HOME=/var/lib/mysql

ENV SUMMARY="MySQL 8.0 SQL database server" \
    DESCRIPTION="MySQL is a multi-user, multi-threaded SQL database server. The container \
image provides a containerized packaging of the MySQL mysqld daemon and client application. \
The mysqld server daemon accepts connections from clients and provides access to content from \
MySQL databases on behalf of the clients."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="MySQL 8.0" \
      io.openshift.expose-services="3306:mysql" \
      io.openshift.tags="database,mysql,mysql80,rh-mysql80" \
      com.redhat.component="rh-mysql80-container" \
      name="centos/mysql-80-centos7" \
      version="8.0" \
      usage="docker run -d -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db -p 3306:3306 centos/mysql-80-centos7" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>"

EXPOSE 3306

# This image must forever use UID 27 for mysql user so our volumes are
# safe in the future. This should *never* change, the last test is there
# to make sure of that.
RUN yum install -y yum-utils && \
    yum install -y centos-release-scl && \
    yum-config-manager --add-repo https://cbs.centos.org/repos/sclo7-rh-mysql80-rh-candidate/x86_64/os/ && \
    INSTALL_PKGS="rsync tar gettext hostname bind-utils groff-base shadow-utils rh-mysql80" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all && \
    mkdir -p /var/lib/mysql/data && chown -R mysql.0 /var/lib/mysql && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"

# Get prefix path and path to scripts rather than hard-code them in scripts
ENV CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/mysql \
    MYSQL_PREFIX=/opt/rh/rh-mysql80/root/usr \
    ENABLED_COLLECTIONS=rh-mysql80

# When bash is started non-interactively, to run a shell script, for example it
# looks for this variable and source the content of this file. This will enable
# the SCL for all scripts without need to do 'scl enable'.
ENV BASH_ENV=${CONTAINER_SCRIPTS_PATH}/scl_enable \
    ENV=${CONTAINER_SCRIPTS_PATH}/scl_enable \
    PROMPT_COMMAND=". ${CONTAINER_SCRIPTS_PATH}/scl_enable"

COPY 8.0/root-common /
COPY 8.0/s2i-common/bin/ $STI_SCRIPTS_PATH
COPY 8.0/root /

# this is needed due to issues with squash
# when this directory gets rm'd by the container-setup
# script.
# Also reset permissions of filesystem to default values
RUN rm -rf /etc/my.cnf.d/* && \
    /usr/libexec/container-setup && \
    rpm-file-permissions

# Not using VOLUME statement since it's not working in OpenShift Online:
# https://github.com/sclorg/httpd-container/issues/30
# VOLUME ["/var/lib/mysql/data"]

USER 27

ENTRYPOINT ["container-entrypoint"]
CMD ["run-mysqld"]