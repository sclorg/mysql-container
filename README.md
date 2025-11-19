MySQL SQL Database Server Container Image
=========================================

[![Build and push images to Quay.io registry](https://github.com/sclorg/mysql-container/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/sclorg/mysql-container/actions/workflows/build-and-push.yml)

This repository contains Dockerfiles for MySQL images for OpenShift and general usage.
Users can choose between RHEL, Fedora and CentOS Stream based images.

For more information about using these images with OpenShift, please see the
official [OpenShift Documentation](https://docs.okd.io/latest/using_images/db_images/mysql.html).

For more information about contributing, see
[the Contribution Guidelines](https://github.com/sclorg/welcome/blob/master/contribution.md).
For more information about concepts used in these container images, see the
[Landing page](https://github.com/sclorg/welcome).


Versions
--------
Currently supported versions are visible in the following table, expand an entry to see its container registry address.
<!--
Table start
-->
||CentOS Stream 9|CentOS Stream 10|Fedora|RHEL 8|RHEL 9|RHEL 10|
|:--|:--:|:--:|:--:|:--:|:--:|:--:|
|8.0|<details><summary>✓</summary>`quay.io/sclorg/mysql-80-c9s`</details>||<details><summary>✓</summary>`quay.io/fedora/mysql-80`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel8/mysql-80`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel9/mysql-80`</details>||
|8.4|<details><summary>✓</summary>`quay.io/sclorg/mysql-84-c9s`</details>|<details><summary>✓</summary>`quay.io/sclorg/mysql-84-c10s`</details>|<details><summary>✓</summary>`quay.io/fedora/mysql-84`</details>||<details><summary>✓</summary>`registry.redhat.io/rhel9/mysql-84`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel10/mysql-84`</details>|
<!--
Table end
-->


Installation
------------
Choose either the CentOS Stream or RHEL based image:

*  **RHEL10 based image**

    These images are available in the [Red Hat Container Catalog](https://catalog.redhat.com/en/search?searchType=containers).
    To download it run:

    ```
    $ podman pull registry.access.redhat.com/rhel10/mysql-84
    ```

    To build a RHEL8 based MySQL image, you need to run Docker build on a properly
    subscribed RHEL machine.

    ```
    $ git clone --recursive https://github.com/sclorg/mysql-container.git
    $ cd mysql-container
    $ git submodule update --init
    $ make build TARGET=rhel10 VERSIONS=8.4
    ```

*  **CentOS Stream based image**

    This image is available on DockerHub. To download it run:

    ```
    $ podman pull quay.io/sclorg/mysql-84-c9s
    ```

    To build a CentOS based MySQL image from scratch, run:

    ```
    $ git clone --recursive https://github.com/sclorg/mysql-container.git
    $ cd mysql-container
    $ git submodule update --init
    $ make build TARGET=c9s VERSIONS=8.4
    ```

For using other versions of MySQL, just replace the `8.4` value by particular version
in the commands above.

Note: while the installation steps are calling `podman`, you can replace any such calls by `docker` with the same arguments.

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**


Usage
-----

For information about usage of Dockerfile for MySQL 8.0,
see [usage documentation](8.0).

For information about usage of Dockerfile for MySQL 8.4,
see [usage documentation](8.4).


Test
----

This repository also provides a test framework, which checks basic functionality
of the MySQL image.

Users can choose between testing MySQL based on a RHEL or CentOS Stream image.

*  **RHEL based image**

    To test a RHEL8 based MySQL image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd mysql-container
    $ git submodule update --init
    $ make test TARGET=rhel8 VERSIONS=8.0
    ```

*  **CentOS Stream based image**

    ```
    $ cd mysql-container
    $ git submodule update --init
    $ make test TARGET=c9s VERSIONS=8.4
    ```

For using other versions of MySQL, just replace the `8.4` value by particular version
in the commands above.

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of MySQL, which must be specified in  `VERSIONS` variable.
This variable must be set to a list with possible versions (subdirectories).**
