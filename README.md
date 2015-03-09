# OpenShift MySQL image

This repository contains Dockerfiles for MySQL images for OpenShift.
Users can choose between RHEL and CentOS based images.

# Installation and Usage
Choose between CentOS7 or RHEL7 based image:

*  **RHEL7 based image**

To build a rhel7-based image, you need to run Docker build on a properly
subscribed RHEL machine.

```console
git clone https://github.com/openshift/mysql.git
cd mysql
make build TARGET=rhel7
```

*  **CentOS7 based image**

```console
git clone https://github.com/openshift/mysql.git
cd mysql
make build
```

## Environment variables and volumes

The image recognizes following environment variables that you can set
during initialization, by passing `-e VAR=VALUE` to the Docker run
command.

|    Variable name       |    Description                            |
| :--------------------- | ----------------------------------------- |
|  `MYSQL_USER`          | User name for MySQL account to be created |
|  `MYSQL_PASSWORD`      | Password for the user account             |
|  `MYSQL_DATABASE`      | Database name                             |
|  `MYSQL_ROOT_PASSWORD` | Password for the root user (optional)     |

You can also set following mount points by passing `-v /host:/container`
flag to docker.

|  Volume mount point | Description          |
| :------------------ | -------------------- |
|  `/var/lib/mysql`   | MySQL data directory |

## Usage

We will assume that you are using the `openshift/mysql-55-centos7`
image. Supposing that you want to set only mandatory required environment
variables and store the database on in the `/home/user/database`
directory on the host filesystem, you need to execute the following
command:

```console
docker run -d -e MYSQL_USER=<user> -e MYSQL_PASSWORD=<password> -e MYSQL_DATABASE=<database> -v /home/user/database:/var/lib/mysql openshift/mysql-55-centos7
```

If the database directory is not initialized, the entrypoint script will
first run `mysql_install_db` and setup necessary database users and
passwords. After the database is initialized, or if it was already
present, `mysqld` is executed and will run as PID 1. You can stop the
detached container by running `docker stop <CONTAINER ID>`.

### MySQL root user
The root user has no password set by default. You can set it by setting
`MYSQL_ROOT_PASSWORD` environment variable when initializing your
database.

## Software Collections
We use [Software Collections](https://www.softwarecollections.org/) to
install and launch MySQL. If you want to execute a command inside of a
running container (for debugging for example), you need to prefix it
with `scl enable` command. Some examples:

```console
# Running mysql commands inside the container
scl enable mysql55 -- mysql -uuser -p

# Executing a command inside a running container from host
# Note: You will be able to run mysql commands without invoking the scl commands
docker exec -ti <CONTAINER> scl enable mysql55 /bin/bash
```
