FROM centos:centos7

# MySQL image for OpenShift.
#
# Volumes:
#  * /var/lib/mysql/data - Datastore for MySQL
# Environment:
#  * $MYSQL_USER - Database user name
#  * $MYSQL_PASSWORD - User's password
#  * $MYSQL_DATABASE - Name of the database to create
#  * $MYSQL_ROOT_PASSWORD (Optional) - Password for the 'root' MySQL account

MAINTAINER SoftwareCollections.org <sclorg@redhat.com>

ENV MYSQL_VERSION=5.5 \
    HOME=/var/lib/mysql

LABEL io.k8s.description="MySQL is a multi-user, multi-threaded SQL database server" \
      io.k8s.display-name="MySQL 5.5" \
      io.openshift.expose-services="3306:mysql" \
      io.openshift.tags="database,mysql,mysql55"

EXPOSE 3306

COPY run-*.sh /usr/local/bin/
COPY contrib /var/lib/mysql/

RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \
    yum -y --setopt=tsflags=nodocs install https://www.softwarecollections.org/en/scls/rhscl/mysql55/epel-7-x86_64/download/rhscl-mysql55-epel-7-x86_64.noarch.rpm && \
    yum -y --setopt=tsflags=nodocs install gettext hostname bind-utils mysql55 && \
    yum clean all && \
    mkdir -p /var/lib/mysql/data && chown mysql.mysql /var/lib/mysql/data && \
    chmod o+w -R /var/lib/mysql

# When bash is started non-interactively, to run a shell script, for example it
# looks for this variable and source the content of this file. This will enable
# the SCL for all scripts without need to do 'scl enable'.
ENV BASH_ENV=/var/lib/mysql/scl_enable \
    ENV=/var/lib/mysql/scl_enable \
    PROMPT_COMMAND=". /var/lib/mysql/scl_enable"

VOLUME ["/var/lib/mysql/data"]

# uid 1001 represents an arbitrary user with no special permissions in the image.  Using it here
# allows us to ensure the image is not relying on any permissions of a particular user when run,
# which would cause problems when the image is run on OpenShift as OpenShift by default runs images
# with a randomized uid, not the uid specified in the image.
USER 1001

ENTRYPOINT ["run-mysqld.sh"]
CMD ["mysqld"]
