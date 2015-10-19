MySQL for OpenShift - Docker images
========================================

This repository contains Dockerfiles for MySQL images for OpenShift.
Users can choose between RHEL and CentOS based images.


Versions
---------------
MySQL versions currently provided are:
* mysql-5.5
* mysql-5.6

RHEL versions currently supported are:
* RHEL7

CentOS versions currently supported are:
* CentOS7


Installation
----------------------
Choose either the CentOS7 or RHEL7 based image:

*  **RHEL7 based image**

    To build a RHEL7 based image, you need to run Docker build on a properly
    subscribed RHEL machine.

    ```
    $ git clone https://github.com/openshift/mysql.git
    $ cd mysql
    $ make build TARGET=rhel7 VERSION=5.5
    ```

*  **CentOS7 based image**

    This image is available on DockerHub. To download it run:

    ```
    $ docker pull openshift/mysql-55-centos7
    ```

    To build a MySQL image from scratch run:

    ```
    $ git clone https://github.com/openshift/mysql.git
    $ cd mysql
    $ make build VERSION=5.5
    ```

For using other versions of mysql, just replace the `5.5` value by particular version
in the commands above.

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**


Usage
---------------------------------

For information about usage of Dockerfile for MySQL 5.6,
see [usage documentation](5.6/README.md).

For information about usage of Dockerfile for MySQL 5.5,
see [usage documentation](5.5/README.md).


Usage on Atomic host
--------------------
Systems derived from projectatomic.io usually include the `atomic` command that is
used to run containers besides other things.

To install a new container `mysql1` based on this image on such a system, run:

```
$ atomic install -n mysqld1 openshift/mysql-55-centos7 -p 3306:3306 -e MYSQL_USER=user -e MYSQL_PASSWORD=secretpass -e MYSQL_DATABASE=db1 
```

This creates directory for data at `/var/lib/mysqld1` on host and will be
mounted as volume for data in the container. Permissions and SELinux context
is set to default values if the directory does not exist.

All options after image name (starting with `-p` in the example above) are
passed to the `docker` as arguments.

Then to run the container, run:

```
$ atomic run mysqld1
```

In order to work with that container, you may either connect to exposed port 3306
by external client or run this command to connect locally:

```
$ atomic run mysqld1 bash -c 'mysql'
```

To stop and uninstall the mysqld1 service, run:

```
$ atomic stop mysqld1
$ atomic uninstall mysqld1
```


Test
---------------------------------

This repository also provides a test framework, which checks basic functionality
of the MySQL image.

Users can choose between testing MySQL based on a RHEL or CentOS image.

*  **RHEL based image**

    To test a RHEL7 based MySQL image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd mysql
    $ make test TARGET=rhel7 VERSION=5.5
    ```

*  **CentOS based image**

    ```
    $ cd mysql
    $ make test VERSION=5.5
    ```

For using other versions of mysql, just replace the `5.5` value by particular version
in the commands above.

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**
