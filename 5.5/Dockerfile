FROM centos:centos7

# MySQL image for OpenShift.
#
# Volumes:
#  * /var/lib/mysql - Datastore for MySQL
# Environment:
#  * $MYSQL_USER - Database user name
#  * $MYSQL_PASSWORD - User's password
#  * $MYSQL_DATABASE - Name of the database to create

# Image metadata
ENV MYSQL_VERSION           5.5
ENV IMAGE_DESCRIPTION       MySQL 5.5
ENV IMAGE_TAGS              mysql,mysql55
ENV IMAGE_EXPOSE_SERVICES   3306:mysql

MAINTAINER  Martin Nagy <mnagy@redhat.com>
EXPOSE 3306

# This image must forever use UID 27 for mysql user so our volumes are
# safe in the future. This should *never* change, the last test is there
# to make sure of that.
RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \
    yum -y --setopt=tsflags=nodocs install https://www.softwarecollections.org/en/scls/rhscl/mysql55/epel-7-x86_64/download/rhscl-mysql55-epel-7-x86_64.noarch.rpm && \
    yum -y --setopt=tsflags=nodocs install hostname mysql55 && \
    yum clean all && \
    test "$(id mysql)" = "uid=27(mysql) gid=27(mysql) groups=27(mysql)"

COPY run-mysqld.sh /usr/local/bin/
COPY mysql /opt/openshift/

VOLUME ["/var/lib/mysql"]

ENTRYPOINT ["run-mysqld.sh"]
