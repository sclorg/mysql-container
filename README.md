MySQL for OpenShift - Docker images
========================================

This repository contains Dockerfiles for MySQL images for OpenShift.
Users can choose between RHEL and CentOS based images.


Versions
---------------
MySQL versions currently provided are:
* mysql-5.5

RHEL versions currently supported are:
* RHEL7

CentOS versions currently supported are:
* CentOS7


Installation
----------------------
Choose between CentOS7 or RHEL7 based image:

*  **RHEL7 based image**

    To build a RHEL7-based image, you need to run Docker build on a properly
    subscribed RHEL machine.

    ```
    $ git clone https://github.com/openshift/mysql.git
    $ cd mysql
    $ make build TARGET=rhel7 VERSION=5.5
    ```

    *  **CentOS7 based image**

    This image is available on DockerHub. To download it use:

    ```
    $ docker pull openshift/mysql-55-centos7
    ```

    To build MySQL image from scratch use:

    ```
    $ git clone https://github.com/openshift/mysql.git
    $ cd mysql
    $ make build VERSION=5.5
    ```

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of MySQL. Since we are now providing only version `5.5`,
you can omit this parameter.**


Environment variables and volumes
----------------------------------

The image recognizes following environment variables that you can set during
initialization, by passing `-e VAR=VALUE` to the Docker run command.

|    Variable name       |    Description                            |
| :--------------------- | ----------------------------------------- |
|  `MYSQL_USER`          | User name for MySQL account to be created |
|  `MYSQL_PASSWORD`      | Password for the user account             |
|  `MYSQL_DATABASE`      | Database name                             |
|  `MYSQL_ROOT_PASSWORD` | Password for the root user (optional)     |

Following environment variables influence MySQL configuration file. They are all optional.

|    Variable name                |    Description                                                    |    Default
| :------------------------------ | ----------------------------------------------------------------- | -------------------------------
|  `MYSQL_LOWER_CASE_TABLE_NAMES` | Sets how the table names are stored and compared                  |  0
|  `MYSQL_MAX_CONNECTIONS`        | The maximum permitted number of simultaneous client connections   |  151
|  `MYSQL_FT_MIN_WORD_LEN`        | The minimum length of the word to be included in a FULLTEXT index |  4
|  `MYSQL_FT_MAX_WORD_LEN`        | The maximum length of the word to be included in a FULLTEXT index |  20
|  `MYSQL_AIO`                    | Controls the `innodb_use_native_aio` setting value in case the native AIO is broken. See http://help.directadmin.com/item.php?id=529 |  1

You can also set following mount points by passing `-v /host:/container` flag to docker.

|  Volume mount point      | Description          |
| :----------------------- | -------------------- |
|  `/var/lib/mysql/data`   | MySQL data directory |


Usage
---------------------------------

We will assume that you are using the `openshift/mysql-55-centos7` image.
If you want to set only mandatory environment variables and not store
the database in a host directory, you need to execute the following command:

```
$ docker run -d --name mysql_database -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db -p 3306:3306 openshift/mysql-55-centos7
```

This will create a container named `mysql_database` running MySQL with database
`db` and user with credentials `user:pass`. Port 3306 will be exposed and mapped
to host. If you want your database to be persistent across container executions,
also add a `-v /host/db/path:/var/lib/mysql/data` argument. This is going to be
the MySQL data directory.

If the database directory is not initialized, the entrypoint script will first
run [`mysql_install_db`](https://dev.mysql.com/doc/refman/5.5/en/mysql-install-db.html)
and setup necessary database users and passwords. After the database is initialized,
or if it was already present, `mysqld` is executed and will run as PID 1. You can
 stop the detached container by running `docker stop mysql_database`.


MySQL root user
---------------------------------
The root user has no password set by default, only allowing local connections.
You can set it by setting `MYSQL_ROOT_PASSWORD` environment variable when initializing
your container. This will allow you to login to the root account remotely. Local
connections will still not require password.


Test
---------------------------------

This repository also provides test framework, which checks basic functionality
of the MySQL image.

User can choose between testing MySQL based on RHEL or CentOS image.

*  **RHEL based image**

    To test a rhel7-based MySQL image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd mongodb
    $ make test TARGET=rhel7 VERSION=5.5
    ```

*  **CentOS based image**

    ```
    $ cd mongodb
    $ make test VERSION=5.5
    ```

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of MySQL. Since we are now providing only version `5.5`,
you can omit this parameter.**
