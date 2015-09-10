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


Environment variables and volumes
----------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker run command.

|    Variable name       |    Description                            |
| :--------------------- | ----------------------------------------- |
|  `MYSQL_USER`          | User name for MySQL account to be created |
|  `MYSQL_PASSWORD`      | Password for the user account             |
|  `MYSQL_DATABASE`      | Database name                             |
|  `MYSQL_ROOT_PASSWORD` | Password for the root user (optional)     |

The following environment variables influence the MySQL configuration file. They are all optional.

|    Variable name                |    Description                                                    |    Default
| :------------------------------ | ----------------------------------------------------------------- | -------------------------------
|  `MYSQL_LOWER_CASE_TABLE_NAMES` | Sets how the table names are stored and compared                  |  0
|  `MYSQL_MAX_CONNECTIONS`        | The maximum permitted number of simultaneous client connections   |  151
|  `MYSQL_FT_MIN_WORD_LEN`        | The minimum length of the word to be included in a FULLTEXT index |  4
|  `MYSQL_FT_MAX_WORD_LEN`        | The maximum length of the word to be included in a FULLTEXT index |  20
|  `MYSQL_AIO`                    | Controls the `innodb_use_native_aio` setting value in case the native AIO is broken. See http://help.directadmin.com/item.php?id=529 |  1

You can also set the following mount points by passing the `-v /host:/container` flag to Docker.

|  Volume mount point      | Description          |
| :----------------------- | -------------------- |
|  `/var/lib/mysql/data`   | MySQL data directory |

**Notice: When mouting a directory from the host into the container, ensure that the mounted
directory has the appropriate permissions and that the owner and group of the directory
matches the user UID or name which is running inside the container.**

Usage
---------------------------------

For this, we will assume that you are using the `openshift/mysql-55-centos7` image.
If you want to set only the mandatory environment variables and not store
the database in a host directory, execute the following command:

```
$ docker run -d --name mysql_database -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db -p 3306:3306 openshift/mysql-55-centos7
```

This will create a container named `mysql_database` running MySQL with database
`db` and user with credentials `user:pass`. Port 3306 will be exposed and mapped
to the host. If you want your database to be persistent across container executions,
also add a `-v /host/db/path:/var/lib/mysql/data` argument. This will be the MySQL
data directory.

If the database directory is not initialized, the entrypoint script will first
run [`mysql_install_db`](https://dev.mysql.com/doc/refman/5.5/en/mysql-install-db.html)
and setup necessary database users and passwords. After the database is initialized,
or if it was already present, `mysqld` is executed and will run as PID 1. You can
 stop the detached container by running `docker stop mysql_database`.


MySQL root user
---------------------------------
The root user has no password set by default, only allowing local connections.
You can set it by setting the `MYSQL_ROOT_PASSWORD` environment variable. This
will allow you to login to the root account remotely. Local connections will
still not require a password.

To disable remote root access, simply unset `MYSQL_ROOT_PASSWORD` and restart
the container.


Changing passwords
------------------

Since passwords are part of the image configuration, the only supported method
to change passwords for the database user (`MYSQL_USER`) and root user is by
changing the environment variables `MYSQL_PASSWORD` and `MYSQL_ROOT_PASSWORD`,
respectively.

Changing database passwords through SQL statements or any way other than through
the environment variables aforementioned will cause a mismatch between the
values stored in the variables and the actual passwords. Whenever a database
container starts it will reset the passwords to the values stored in the
environment variables.


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
