FROM {{ spec.s2i_base }}

# MySQL image for OpenShift.
#
# Volumes:
#  * /var/lib/mysql/data - Datastore for MySQL
# Environment:
#  * $MYSQL_USER - Database user name
#  * $MYSQL_PASSWORD - User's password
#  * $MYSQL_DATABASE - Name of the database to create
#  * $MYSQL_ROOT_PASSWORD (Optional) - Password for the 'root' MySQL account

# Standalone ENV call so these values can be re-used in the other ENV calls
ENV MYSQL_VERSION={{ spec.version }} \
    MYSQL_SHORT_VERSION={{ spec.short }}

ENV APP_DATA=/opt/app-root/src \
    HOME=/var/lib/mysql \
    NAME=mysql \
    SUMMARY="MySQL ${MYSQL_VERSION} SQL database server" \
    DESCRIPTION="MySQL is a multi-user, multi-threaded SQL database server. The container \
image provides a containerized packaging of the MySQL mysqld daemon and client application. \
The mysqld server daemon accepts connections from clients and provides access to content from \
MySQL databases on behalf of the clients."

LABEL summary="${SUMMARY}" \
      description="${DESCRIPTION}" \
      io.k8s.description="${DESCRIPTION}" \
      io.k8s.display-name="MySQL ${MYSQL_VERSION}" \
      io.openshift.expose-services="3306:mysql" \
      io.openshift.tags="database,${NAME},${NAME}${MYSQL_SHORT_VERSION}{% if spec.prod == 'fedora' and spec.version == '8.0' %},rh-${NAME}${MYSQL_SHORT_VERSION}{% elif spec.prod != 'fedora' %},${NAME}-${MYSQL_SHORT_VERSION}{% endif %}" \
      com.redhat.component="{% if spec.prod == 'rhel8' or spec.prod == 'rhel9' or spec.prod == 'rhel10' or spec.prod == 'c9s' or spec.prod == 'c10s' %}${NAME}-${MYSQL_SHORT_VERSION}-container{% else %}${NAME}{% endif %}" \
      name="{{ spec.img_name }}" \
      version="${MYSQL_VERSION}" \
{% if spec.license_terms %}      com.redhat.license_terms="{{ spec.license_terms }}" \
{% endif %}      usage="{% if spec.prod == 'c9s' or spec.prod == 'c10s' %}podman run -d -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db -p 3306:3306 quay.io/{{ spec.img_name }}:{{ spec.prod }}{% elif spec.prod == 'fedora' %}docker run -d -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db -p 3306:3306 quay.io/{{ spec.img_name }}{% else %}podman run -d -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db -p 3306:3306 {{ spec.img_name }}{% endif %}" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>"

EXPOSE 3306

# This image must forever use UID 27 for mysql user so our volumes are safe in the future. This should *never* change.
# Instead of relying on the DB server package, we will do the setup ourselves before any package is installed
{% if spec.prod == 'fedora' %}RUN /usr/sbin/groupadd -g 27 -o -r mysql && \
    /usr/sbin/useradd -M -N -g mysql -o -r -d ${HOME} -s /sbin/nologin -c "MySQL Server" -u 27 mysql && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)" && \
    INSTALL_PKGS="{{ spec.pkgs }}" && \
    dnf install -y --setopt=tsflags=nodocs --setopt=install_weak_deps=False ${INSTALL_PKGS} ${NAME}${MYSQL_VERSION}-server && \
    dnf -y clean all --enablerepo='*' && \
    mkdir -p ${HOME}/data && chown -R mysql{% if spec.version == '8.0' %}.0{% else %}:root{% endif %} ${HOME} && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"
{% elif spec.prod == 'rhel8' and spec.version == '8.0' %}RUN yum -y module enable mysql:$MYSQL_VERSION && \
    INSTALL_PKGS="{{ spec.pkgs }}" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all --enablerepo='*' && \
    mkdir -p /var/lib/mysql/data && chown -R mysql.0 /var/lib/mysql && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"
{% elif (spec.prod == 'rhel9' or spec.prod == 'c9s') and spec.version == '8.4' %}RUN yum -y module enable ${NAME}:${MYSQL_VERSION} && \
    INSTALL_PKGS="{{ spec.pkgs }}" && \
    dnf install -y --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
    rpm -V ${INSTALL_PKGS} && \
    dnf -y clean all --enablerepo='*' && \
    mkdir -p ${HOME}/data && chown -R mysql:{{ spec.chown_group }} ${HOME} && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"
{% elif spec.version == '8.0' %}RUN INSTALL_PKGS="{{ spec.pkgs }}" && \
    yum install -y --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
    rpm -V ${INSTALL_PKGS} && \
    yum -y clean all --enablerepo='*' && \
    mkdir -p ${HOME}/data && chown -R mysql.0 ${HOME} && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"
{% elif spec.prod == 'rhel10' or spec.prod == 'c10s' %}RUN INSTALL_PKGS="{{ spec.pkgs }}" && \
    dnf install -y --setopt=tsflags=nodocs ${INSTALL_PKGS} ${NAME}${MYSQL_VERSION}-server && \
    dnf -y clean all --enablerepo='*' && \
    mkdir -p ${HOME}/data && chown -R mysql:{{ spec.chown_group }} ${HOME} && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"
{% else %}RUN INSTALL_PKGS="{{ spec.pkgs }}" && \
    dnf install -y --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
    rpm -V ${INSTALL_PKGS} && \
    dnf -y clean all --enablerepo='*' && \
    mkdir -p ${HOME}/data && chown -R mysql:{{ spec.chown_group }} ${HOME} && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"
{% endif %}

# Get prefix path and path to scripts rather than hard-code them in scripts
ENV CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/mysql \
    MYSQL_PREFIX=/usr

COPY {{ spec.version }}/root-common /
COPY {{ spec.version }}/s2i-common/bin/ ${STI_SCRIPTS_PATH}
COPY {{ spec.version }}/root /

# Hard links are not supported in Testing Farm approach during sync to guest
# operation system. Therefore tests are failing on error
# /usr/libexec/s2i/run no such file or directory
RUN ln -s /bin/run-mysqld ${STI_SCRIPTS_PATH}/run

# this is needed due to issues with squash
# when this directory gets rm'd by the container-setup
# script.
# Also reset permissions of filesystem to default values
RUN rm -rf /etc/my.cnf.d/* && \
    /usr/libexec/container-setup && \
    rpm-file-permissions && \
    /usr/libexec/mysqld -V | grep -qe "${MYSQL_VERSION}\." && echo "Found VERSION ${MYSQL_VERSION}"

USER 27

ENTRYPOINT ["container-entrypoint"]
CMD ["run-mysqld"]
