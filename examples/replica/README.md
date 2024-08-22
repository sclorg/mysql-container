# MySQL Replication Example

**WARNING:**

**This is only a Proof-Of-Concept example and it is not meant to be used in any
production. Use at your own risk.**

## What is MySQL replication?

Replication enables data from one MySQL database server (the source) to be
replicated to one or more MySQL database servers (the replicas). Replication is
asynchronous - replicas do not need not be connected permanently to receive updates from
the source. This means that updates can occur over long-distance connections and
even over temporary or intermittent connections such as a dial-up service.
Depending on the configuration, you can replicate all databases, selected
databases, or even selected tables within a database.

See: https://dev.mysql.com/doc/refman/en/replication.html

## How does this example work?

The provided JSON file (`mysql_replica.json`) contains a `Template` resource that
groups the Kubernetes and OpenShift resources which are meant to be created.
This template will start with one MySQL source server and one replica server.

## Persistent storage

In order to provide persistent storage for MySQL, this example requires two
persistent volumes of at least 512 MiB each.

The OpenShift cluster administrator needs to create persistent volumes to be
claimed when the template is instantiated. Refer to the [OpenShift
documentation](https://docs.okd.io/latest/install_config/persistent_storage/persistent_storage_nfs.html)
to learn how to create persistent volumes.

### Service 'mysql-source'

This resource provides 'headless' Service for the MySQL server(s) which acts
as the 'source'. The headless means that the Service does not use IP
addresses but it uses the DNS sub-system. This behavior is configured by setting
the `clusterIP` attribute to `None`.

In this case, you can query the DNS (eg. `dig mysql-source A +search +short`) to
obtain the list of the Service endpoints (the MySQL servers that subscribe to
this service).

### Service 'mysql-replica'

This resource provides the 'headless' Service for the MySQL servers that the
MySQL source uses as 'replicas' which are used to replicate the data from the
MySQL source.

You can use the same DNS lookup as mentioned above to obtain the list of the
Service endpoints.

### ReplicationController 'mysql-source'

This resource defines the `PodTemplate` of the MySQL server that acts as the
'source'. The Pod uses the `quay.io/sclorg/mysql-80-c9s` image, but it sets the
special 'entrypoint' named `mysqld-source`. This will tell the MySQL image to
configure the MySQL server as the 'source'.

To configure the 'source', you have to provide the credentials for the user that
will act as the 'source' admin. This user has special privileges to add or
remove 'replicas'.
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

Once the MySQL source server is started, it has no replicas preconfigured as the
replicas registers automatically.

Note that currently the multiple-source configuration is not supported (even
though the `mysql-source` is defined as ReplicationController. If you increase the
number of replicas, then a new MySQL source server is started, but it will not
receive any replicas. This will be solved in future.

To check that the source MySQL server is working, you can issue the following
command on the source container:

```
mysql> SHOW BINARY LOG STATUS;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000002 |      107 | foo          |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.00 sec)
```

### ReplicationController 'mysql-replica'

This resource defines the `PodTemplate` of the MySQL servers that act as the
`replicas` to the `source` server. In the provided JSON example, this Replication
Controller starts with 3 replicas. Each `replica` server first waits for the `source`
server to become available (getting the `source` server IP using the DNS
lookup). Once the `source` is available, the MySQL 'replica' server is started and
connected to the `source`. The unique `server-id` configuration property is
generated from the unique IP address of the container (and hashed to a number).
Each `replica` must have unique `server-id`.

Once the `replica` is running, it will fetch the database and users from the
`source` server, so you don't have to configure the user accounts for this
resources.

To check the 'replica' status, you can issue the following command on the replica
container:

```
mysql> SHOW REPLICA STATUS\G
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 172.17.0.17
                  Source_User: source
                  Source_Port: 3306
                Connect_Retry: 60
```

This output means that the 'replica' is successfully connected to the 'source'
MySQL server running on '172.17.0.17'.

To see the 'replica' hosts from the 'source', you can issue the following command
on the 'source' container:

```
mysql> SHOW REPLICA HOSTS;
+------------+-------------+------+------------+
| Server_id  | Host        | Port | Source_id  |
+------------+-------------+------+------------+
| 3314680171 | 172.17.0.20 | 3306 | 1301393349 |
| 3532875540 | 172.17.0.18 | 3306 | 1301393349 |
+------------+-------------+------+------------+
2 rows in set (0.01 sec)

```

You can add more replicas if you want, using the following `oc` command.

```
$ oc scale rc mysql-replica --replicas=4
```
