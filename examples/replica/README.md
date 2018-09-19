# MySQL Replication Example

**WARNING:**

**This is only a Proof-Of-Concept example and it is not meant to be used in any
production. Use at your own risk.**

## What is MySQL replication?

Replication enables data from one MySQL database server (the master) to be
replicated to one or more MySQL database servers (the slaves). Replication is
asynchronous - slaves do not need not be connected permanently to receive updates from
the master. This means that updates can occur over long-distance connections and
even over temporary or intermittent connections such as a dial-up service.
Depending on the configuration, you can replicate all databases, selected
databases, or even selected tables within a database.

See: https://dev.mysql.com/doc/refman/en/replication.html

## How does this example work?

The provided JSON file (`mysql_replica.json`) contains a `Template` resource that
groups the Kubernetes and OpenShift resources which are meant to be created.
This template will start with one MySQL master server and one slave server.

## Persistent storage

In order to provide persistent storage for MySQL, this example requires two
persistent volumes of at least 512 MiB each.

The OpenShift cluster administrator needs to create persistent volumes to be
claimed when the template is instantiated. Refer to the [OpenShift
documentation](https://docs.okd.io/latest/install_config/persistent_storage/persistent_storage_nfs.html)
to learn how to create persistent volumes.

### Service 'mysql-master'

This resource provides 'headless' Service for the MySQL server(s) which acts
as the 'master'. The headless means that the Service does not use IP
addresses but it uses the DNS sub-system. This behavior is configured by setting
the `clusterIP` attribute to `None`.

In this case, you can query the DNS (eg. `dig mysql-master A +search +short`) to
obtain the list of the Service endpoints (the MySQL servers that subscribe to
this service).

### Service 'mysql-slave'

This resource provides the 'headless' Service for the MySQL servers that the
MySQL master uses as 'slaves' which are used to replicate the data from the
MySQL master.

You can use the same DNS lookup as mentioned above to obtain the list of the
Service endpoints.

### ReplicationController 'mysql-master'

This resource defines the `PodTemplate` of the MySQL server that acts as the
'master'. The Pod uses the `centos/mysql-57-centos7` image, but it sets the
special 'entrypoint' named `mysqld-master`. This will tell the MySQL image to
configure the MySQL server as the 'master'.

To configure the 'master', you have to provide the credentials for the user that
will act as the 'master' admin. This user has special privileges to add or
remove 'slaves'.
The other thing you have to provide is the regular MySQL username that you can
use to connect to the MySQL server. This user has lower privileges and it is
safe to use it in your application.

Optionally you can define `MYSQL_DATABASE` and `MYSQL_ROOT_PASSWORD`. The first
one sets the name of the initial database that will be created and the
`MYSQL_USER` will be granted access to it. This parameter is optional
and if you don't specify it, the database name will default to the value of
`MYSQL_USER`.

If you want to perform administration tasks, you can also set the
`MYSQL_ROOT_PASSWORD`. In that case you will be able to connect to the MySQL
server as the 'root' user and create more users or more databases.

Once the MySQL master server is started, it has no slaves preconfigured as the
slaves registers automatically.

Note that currently the multiple-master configuration is not supported (even
though the `mysql-master` is defined as ReplicationController. If you increase the
number of replicas, then a new MySQL master server is started, but it will not
receive any slaves. This will be solved in future.

To check that the master MySQL server is working, you can issue the following
command on the master container:

```
mysql> SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000002 |      107 | foo          |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.00 sec)
```

### ReplicationController 'mysql-slave'

This resource defines the `PodTemplate` of the MySQL servers that act as the
`slaves` to the `master` server. In the provided JSON example, this Replication
Controller starts with 3 slaves. Each `slave` server first waits for the `master`
server to become available (getting the `master` server IP using the DNS
lookup). Once the `master` is available, the MySQL 'slave' server is started and
connected to the `master`. The unique `server-id` configuration property is
generated from the unique IP address of the container (and hashed to a number).
Each `slave` must have unique `server-id`.

Once the `slave` is running, it will fetch the database and users from the
`master` server, so you don't have to configure the user accounts for this
resources.

To check the 'slave' status, you can issue the following command on the slave
container:

```
mysql> SHOW SLAVE STATUS\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 172.17.0.17
                  Master_User: master
                  Master_Port: 3306
                Connect_Retry: 60
```

This output means that the 'slave' is successfully connected to the 'master'
MySQL server running on '172.17.0.17'.

To see the 'slave' hosts from the 'master', you can issue the following command
on the 'master' container:

```
mysql> SHOW SLAVE HOSTS;
+------------+-------------+------+------------+
| Server_id  | Host        | Port | Master_id  |
+------------+-------------+------+------------+
| 3314680171 | 172.17.0.20 | 3306 | 1301393349 |
| 3532875540 | 172.17.0.18 | 3306 | 1301393349 |
+------------+-------------+------+------------+
2 rows in set (0.01 sec)

```

You can add more slaves if you want, using the following `oc` command.

```
$ oc scale rc mysql-slave --replicas=4
```
