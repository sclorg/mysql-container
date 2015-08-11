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
You can set it by setting the `MYSQL_ROOT_PASSWORD` environment variable when initializing
your container. This will allow you to login to the root account remotely. Local
connections will still not require a password.


Extending the Docker image
--------------------------

The Docker image provides reasonable set of features that should cover most of the use cases out or the box. For cases when some feature is missing, the image allows consumers to extend the functionality. 

Typically, these changes are: 

* editing other configuration options
* adjusting how the database is initialized during first start
* specifying what happens before every start of the database daemon
* creating more users or databases during database initialization

There are basically two ways how to extend or change the image functionality:

* by creating a new layered Docker image on top of this one, while using this image as base 
* by volume mounting files during running the Docker image


Creating a new layered Docker image on top of this Docker image
---------------------------------------------------------------
In order to use this Docker image as base in other layered Docker image, specify name of this one as base and then add files or run commands as you need, like this:
```
FROM <this-image>
ADD mystuff /usr/bin/
RUN /usr/bin/mystuff
```

### Example of adding a new configuration file in layered Dockerfile:

To change configuration for the `mysqld` daemon and other utilities running within the container, place your new configuration files with `*.cnf` extention into `/etc/my.cnf.d` directory.

Example of the layered Dockerfile:

```
FROM <this-image>
ADD myconfig.cnf /etc/my.cnf.d/myconfig.cnf
```

Notice: Read order of configuration files in `/etc/my.cnf.d/` directory is not specified.

### Adjusting database inicialization

Initialization of mysql database during first start of this image is devided into several files in several directories. All directories include files that are read in alphabetical order, and thus file names are usually prefixed with a number.

Concretly there are these directories within the Docker container:

* `/usr/share/container-layer/mysql/pre-init/` -- this directory includes shell scripts with extention `.sh` that will be sourced and thus executed before every inicialization of container (no matter whether the data directory is empty or not). At the time these scripts are executed, the daemon is not yet running. Example of script in this directory is a script that checks arguments specified by user.
* `/usr/share/container-layer/mysql/post-init/` -- this directory includes shell scripts with extention `.sh` that will be sourced and thus executed before the first start of container (i.e. in case the container is started with empty data directory). At the time these scripts are executed, the daemon runs on localhost only and `mysql` utility should use arguments stored in `$mysql_flags` environment variable. This directory usually includes scripts for creating new databases, users or initialize the database according to your needs.
* `/usr/share/container-layer/mysql/pre-start/` -- this directory includes shell scripts with extention `.sh` that will be sourced and thus executed before every start of container (no matter whether the data directory is empty or not). At the time these scripts are executed, the daemon runs on localhost only and `mysql` utility should use arguments stored in `$mysql_flags` environment variable. Example of script in this directory is a script that allows to change password.
* `/usr/share/container-layer/mysql/include/` -- this directory includes shell scripts with extention `.sh` that will be sourced and thus executed in the beginning of the commands like run-mysqld. Files in this directory contain usually functions or variables definition that are supposed to be used in other scripts used in the image.
* `/usr/share/container-layer/mysql/usage/` -- this directory includes text files with extention `.txt` that will be printed as usage message for the container in case wrong arguments are given. Shell variables in these files will be expanded using `envsubst` utility.

Generally, to perform some additional action according to your needs, put appropriate files into these directories in your Dockerfile. See other files in those directories for inspiration.

### Example of extending the Docker image by creating layered Dockerfile

This example adds posibility to add a new user during database inicialization. The username and password is specified using `MYSQL_CONTENT_ADMIN_USER` and `MYSQL_CONTENT_ADMIN_PASSWORD` environment variables, provided when starting the container the first time.

Since you might need to validate the input provided by user in environment variables, it is possible to do it by droping a shell script appropriate directory, that is sourced in the beginning of the daemon start.

Finally, we want to extend the usage message that is printed in case wrong arguments are given by user. This is done by droping a text file into appropriate directory

Content of the layered Dockerfile:
```
FROM <this-image>
USER 0
ADD 60_content_admin_create.sh /usr/share/container-layer/mysql/post-init/
ADD 60_content_admin_password.sh /usr/share/container-layer/mysql/pre-start/
ADD 60_verify_content_admin.sh /usr/share/container-layer/mysql/pre-init/
ADD 60_usage_content_admin.txt /usr/share/container-layer/mysql/usage/
USER 27
```

Content of the `60_content_admin_create.sh` file
```
mysql $mysql_flags <<EOSQL
    CREATE USER '${MYSQL_CONTENT_ADMIN_USER}'@'%' IDENTIFIED BY '${MYSQL_CONTENT_ADMIN_PASSWORD}';
    GRANT INSERT, SELECT, UPDATE, DELETE ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' ;
    FLUSH PRIVILEGES ;
EOSQL
```

Content of the `60_content_admin_password.sh` file
```
mysql $mysql_flags <<EOSQL
  SET PASSWORD FOR '${MYSQL_CONTENT_ADMIN_USER}'@'%' = PASSWORD('${MYSQL_CONTENT_ADMIN_PASSWORD}');
EOSQL
```

Content of the `60_verify_content_admin.sh` file:
```
if ! [[ -v MYSQL_CONTENT_ADMIN_USER && -v MYSQL_CONTENT_ADMIN_PASSWORD ]]; then
    usage
fi

[ ${#MYSQL_CONTENT_ADMIN_USER} -le 16 ] || usage "MySQL username for MYSQL_CONTENT_ADMIN_USER too long (maximum 16 characters)"
```

Content of the `60_usage_content_admin.txt` file:
```
Content admin user:
  MYSQL_CONTENT_ADMIN_USER (max 16 characters)
  MYSQL_CONTENT_ADMIN_PASSWORD
```

To build such a layered Dockerfile, just run `docker build .` in the directory, that includes all the files above. Built Docker image may be then run as:

```
docker run -ti --rm -e MYSQL_USER=user -e MYSQL_PASSWORD=pass1 -e MYSQL_DATABASE=db -e MYSQL_CONTENT_ADMIN_USER=contentuser -e MYSQL_CONTENT_ADMIN_PASSWORD=pass2 <image>
```

### Example of removing existing features in layered Dockerfile

There are already some files in the directories mentioned above. These files provide the basic features that are used by majority of users.

Example of such a feature is creation of one database with specified name and user that can work with that database. In order to remove this feature, the files need to be removed in the Dockerfile:

```
FROM <this-image>
RUN rm -f /usr/share/container-layer/mysql/post-init/20-base-database.sh \
/usr/share/container-layer/mysql/pre-start/10-passwords.sh \
/usr/share/container-layer/mysql/pre-init/10-validate-base-variables.sh
```

Such an image won't require `MYSQL_USER`, `MYSQL_PASSWORD` and `MYSQL_DATABASE` environment variables specified.


Extending the docker image by volume mounting files
---------------------------------------------------

This Docker image allows to adjust functionality even without creating the layered Dockerfile as described above. It is possible to use volume mounting using `-v` option (see `docker-run` man page for details).

In a nutshell, all we need to do is adding the same files, as we added in examples above, just using volume mounting feature of the `docker utility.

### Example of adjusting the configuration of docker image by volume mounting files

The simplest way of adding a new configuration file is adding it directly into `/etc/my.cnf.d` directory, like this.

```
docker run -d -v myconfig.cnf:/etc/my.cnf.d/myconfig.cnf <this_image>
```

Please, mind, that this file needs to have correct SELinux context, so `mysqld` dameon can read it.

### Example of adding more files by volume mounting files

When adding more files, the `-v` option would have to be specified serveral times, so there is another way to add whole directory with already prepared tree structure.

This example includes the same files as we used in the example of extending docker image in layered Dockerfile. The only difference is that these files are already prepared in tree that corresponds with their location, like this:

```
./myroot/usr/share/container-volume/mysql/pre-usage/60_usage_content_admin.txt
./myroot/usr/share/container-volume/mysql/pre-init/60_verify_content_admin.sh
./myroot/usr/share/container-volume/mysql/pre-start/60_content_admin_password.sh
./myroot/usr/share/container-volume/mysql/post-init/60_content_admin_create.sh
```

Please, mind, that we use `/usr/share/container-volume/` instead of `/usr/share/container-layer/` this time, because we don't want to touch original content of `/usr/share/container-layer/`, which is already there. Then, to volume mount all these files, just mount the root directory, like this:

```
docker run -d --rm -v /myroot/usr/share/container-volume:/usr/share/container-volume -e MYSQL_USER=user -e MYSQL_PASSWORD=pass1 -e MYSQL_DATABASE=db -e MYSQL_CONTENT_ADMIN_USER=content_user -e MYSQL_CONTENT_ADMIN_PASSWORD=pass2 <this_image>
```

This will run a Docker container with adjusted functionality.


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
