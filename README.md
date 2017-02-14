MySQL Docker images
===================

This repository contains Dockerfiles for MySQL images for OpenShift.
Users can choose between RHEL and CentOS based images.

For more information about using these images with OpenShift, please see the
official [OpenShift Documentation](https://docs.openshift.org/latest/using_images/db_images/mysql.html).


Versions
---------------
MySQL versions currently provided are:
* mysql-5.6
* mysql-5.7

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
    $ make build TARGET=rhel7 VERSION=5.7
    ```

*  **CentOS7 based image**

    This image is available on DockerHub. To download it run:

    ```
    $ docker pull centos/mysql-57-centos7
    ```

    or

    ```
    $ docker pull centos/mysql-57-centos7
    ```

    To build a MySQL image from scratch run:

    ```
    $ git clone https://github.com/openshift/mysql.git
    $ cd mysql
    $ make build TARGET=centos7 VERSION=5.7
    ```

For using other versions of mysql, just replace the `5.7` value by particular version
in the commands above.

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**


Usage
---------------------------------

For information about usage of Dockerfile for MySQL 5.6,
see [usage documentation](5.6/README.md).

For information about usage of Dockerfile for MySQL 5.7,
see [usage documentation](5.7/README.md).


Usage on Atomic host
---------------------------------
Systems derived from projectatomic.io usually include the `atomic` command that is
used to run containers besides other things.

To install a new service `mysqld1` based on this image on such a system, run:

```
$ atomic install -n mysqld1 --opt2='-e MYSQL_USER=user` -e MYSQL_PASSWORD=secretpass -e MYSQL_DATABASE=db1 -p 3306:3306' openshift/mysql-55-centos7
```

Then to run the service, use the standard `systemctl` call:

```
$ systemctl start mysqld1.service
```

In order to work with that service, you may either connect to exposed port 3306 or run this command to connect locally:
```
$ atomic run -n mysqld1 openshift/mysql-55-centos7 bash -c 'mysql'
```

To stop and uninstall the mysqld1 service, run:

```
$ systemctl stop mysqld1.service
$ atomic uninstall -n mysqld1 openshift/mysql-55-centos7
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
    $ make test TARGET=rhel7 VERSION=5.7
    ```

*  **CentOS based image**

    ```
    $ cd mysql
    $ make test TARGET=centos7 VERSION=5.7
    ```

For using other versions of mysql, just replace the `5.7` value by particular version
in the commands above.

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**
