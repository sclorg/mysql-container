MySQL SQL Database Server Container Image
=========================================
MySQL 8.0 status: [![Docker Repository on Quay](https://quay.io/repository/centos7/mysql-80-centos7/status "Docker Repository on Quay")](https://quay.io/repository/centos7/mysql-80-centos7)

This repository contains Dockerfiles for MySQL images for OpenShift and general usage.
Users can choose between RHEL, Fedora and CentOS based images.

For more information about using these images with OpenShift, please see the
official [OpenShift Documentation](https://docs.okd.io/latest/using_images/db_images/mysql.html).

For more information about contributing, see
[the Contribution Guidelines](https://github.com/sclorg/welcome/blob/master/contribution.md).
For more information about concepts used in these container images, see the
[Landing page](https://github.com/sclorg/welcome).


Versions
--------
MySQL versions currently provided are:
* [MySQL 8.0](8.0)

RHEL versions currently supported are:
* RHEL7
* RHEL8

CentOS versions currently supported are:
* CentOS7


Installation
------------
Choose either the CentOS7 or RHEL7 based image:

*  **RHEL7 based image**

    These images are available in the [Red Hat Container Catalog](https://access.redhat.com/containers/#/registry.access.redhat.com/rhscl/mysql-80-rhel7).
    To download it run:

    ```
    $ podman pull registry.access.redhat.com/rhscl/mysql-80-rhel7
    ```

    To build a RHEL7 based MySQL image, you need to run Docker build on a properly
    subscribed RHEL machine.

    ```
    $ git clone --recursive https://github.com/sclorg/mysql-container.git
    $ cd mysql-container
    $ git submodule update --init
    $ make build TARGET=rhel7 VERSIONS=8.0
    ```

*  **CentOS7 based image**

    This image is available on DockerHub. To download it run:

    ```
    $ podman pull quay.io/centos7/mysql-80-centos7
    ```

    To build a CentOS based MySQL image from scratch, run:

    ```
    $ git clone --recursive https://github.com/sclorg/mysql-container.git
    $ cd mysql-container
    $ git submodule update --init
    $ make build TARGET=centos7 VERSIONS=8.0
    ```

For using other versions of MySQL, just replace the `8.0` value by particular version
in the commands above.

Note: while the installation steps are calling `podman`, you can replace any such calls by `docker` with the same arguments.

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**


Usage
-----

For information about usage of Dockerfile for MySQL 8.0,
see [usage documentation](8.0).


Test
----

This repository also provides a test framework, which checks basic functionality
of the MySQL image.

Users can choose between testing MySQL based on a RHEL or CentOS image.

*  **RHEL based image**

    To test a RHEL7 based MySQL image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd mysql-container
    $ git submodule update --init
    $ make test TARGET=rhel7 VERSIONS=8.0
    ```

*  **CentOS based image**

    ```
    $ cd mysql-container
    $ git submodule update --init
    $ make test TARGET=centos7 VERSIONS=8.0
    ```

For using other versions of MySQL, just replace the `8.0` value by particular version
in the commands above.

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**
