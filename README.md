MySQL SQL Database Server Docker Image
======================================

This repository contains Dockerfiles for MySQL images for OpenShift and general usage.
Users can choose between RHEL and CentOS based images.

For more information about using these images with OpenShift, please see the
official [OpenShift Documentation](https://docs.openshift.org/latest/using_images/db_images/mysql.html).


Versions
---------------
MySQL versions currently provided are:
* [mysql-5.6](5.6)
* [mysql-5.7](5.7)

RHEL versions currently supported are:
* RHEL7

CentOS versions currently supported are:
* CentOS7


Installation
----------------------
Choose either the CentOS7 or RHEL7 based image:

*  **RHEL7 based image**

    This image is available in Red Hat Container Registry. To download it run:

    ```
    $ docker pull registry.access.redhat.com/rhscl/mysql-57-rhel7
    ```

    To build a RHEL7 based MySQL image, you need to run Docker build on a properly
    subscribed RHEL machine.

    ```
    $ git clone https://github.com/sclorg/mysql-container.git
    $ cd mysql-container
    $ make build TARGET=rhel7 VERSION=5.7
    ```

*  **CentOS7 based image**

    This image is available on DockerHub. To download it run:

    ```
    $ docker pull centos/mysql-57-centos7
    ```

    To build a CentOS based MySQL image from scratch, run:

    ```
    $ git clone https://github.com/sclorg/mysql-container.git
    $ cd mysql-container
    $ make build TARGET=centos7 VERSION=5.7
    ```

For using other versions of MySQL, just replace the `5.7` value by particular version
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


Test
---------------------------------

This repository also provides a test framework, which checks basic functionality
of the MySQL image.

Users can choose between testing MySQL based on a RHEL or CentOS image.

*  **RHEL based image**

    To test a RHEL7 based MySQL image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd mysql-container
    $ make test TARGET=rhel7 VERSION=5.7
    ```

*  **CentOS based image**

    ```
    $ cd mysql-container
    $ make test TARGET=centos7 VERSION=5.7
    ```

For using other versions of MySQL, just replace the `5.7` value by particular version
in the commands above.

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**
