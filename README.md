# OpenShift MySQL image

This repository contains Dockerfiles for MySQL images for OpenShift. Users can choose between RHEL and CentOS based images.

# Installation and Usage
Choose between CentOS7 or RHEL7 based image:

*  **RHEL7 based image**

To build a RHEL7-based image, you need to run Docker build on a properly subscribed RHEL machine.

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

The image recognizes following environment variables that you can set during initialization, by passing `-e VAR=VALUE` to the Docker run command.

|    Variable name       |    Description                            |
| :--------------------- | ----------------------------------------- |
|  `MYSQL_USER`          | User name for MySQL account to be created |
|  `MYSQL_PASSWORD`      | Password for the user account             |
|  `MYSQL_DATABASE`      | Database name                             |
|  `MYSQL_ROOT_PASSWORD` | Password for the root user (optional)     |

You can also set following mount points by passing `-v /host:/container` flag to docker.

|  Volume mount point      | Description          |
| :----------------------- | -------------------- |
|  `/var/lib/mysql/data`   | MySQL data directory |

## Usage

We will assume that you are using the `openshift/mysql-55-centos7` image. Supposing that you want to set only mandatory environment variables and not store the database directory on the host filesystem, you need to execute the following command:

```console
docker run -d --name mysql_database -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db -p 3306:3306 openshift/mysql-55-centos7
```

This will create a container named `mysql_database` running MySQL with database `db` and user with credentials `user:pass`. Port 3306 will be exposed and mapped to host. If you want your database to be persistent across container executions, also add a `-v /host/db/path:/var/lib/mysql/data` argument. This is going to be the MySQL data directory.

If the database directory is not initialized, the entrypoint script will first run [`mysql_install_db`](https://dev.mysql.com/doc/refman/5.5/en/mysql-install-db.html) and setup necessary database users and passwords. After the database is initialized, or if it was already present, `mysqld` is executed and will run as PID 1. You can stop the detached container by running `docker stop mysql_database`.

### MySQL root user
The root user has no password set by default, only allowing local connections. You can set it by setting `MYSQL_ROOT_PASSWORD` environment variable when initializing your container. This will allow you to login to the root account remotely. Local connections will still not require password.

## Software Collections
We use [Software Collections](https://www.softwarecollections.org/) to install and launch MySQL. Any command run by the entrypoint will have environment set up properly, so you shouldn't worry. However, if you want to execute a command inside of a running container (for debugging for example), you need to prefix it with `scl enable <collection>` command. In the case of MySQL 5.5, the collection name will be "mysql55":

```console
docker exec -ti mysql_database scl enable mysql55 -- mysql -h 127.0.0.1 -uuser -ppass
```
