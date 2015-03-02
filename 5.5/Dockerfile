FROM centos:centos7

# MySQL image for OpenShift.
#
# Volumes:
#  * /var/lib/mysql - Datastore for MySQL
# Environment:
#  * $MYSQL_USER - Database user name
#  * $MYSQL_PASSWORD - User's password
#  * $MYSQL_DATABASE - Name of the database to create
#  * $MYSQL_ROOT_PASSWORD - MySQL root user password (optional)

# Image metadata
ENV MYSQL_VERSION           = "5.5" \
    IMAGE_DESCRIPTION       = "MySQL 5.5" \
    IMAGE_TAGS              = "mysql,mysql55" \
    IMAGE_EXPOSE_SERVICES   = "3306:mysql"

MAINTAINER  Martin Nagy <mnagy@redhat.com>
EXPOSE 3306

RUN groupadd -g 27 -o -r mysql && \
    useradd -M -N -g mysql -o -r -d /var/lib/mysql -s /sbin/nologin -c "MySQL Server" -u 27 mysql

RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \
    yum -y --setopt=tsflags=nodocs install https://www.softwarecollections.org/en/scls/rhscl/mysql55/epel-7-x86_64/download/rhscl-mysql55-epel-7-x86_64.noarch.rpm && \
    yum -y --setopt=tsflags=nodocs install hostname mysql55 && \
    yum clean all

COPY mysql /opt/openshift/
ENV PATH /opt/openshift/bin:$PATH
WORKDIR /opt/openshift

VOLUME ["/var/lib/mysql"]

ENTRYPOINT ["run-mysqld.sh"]
