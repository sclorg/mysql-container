import tempfile
import re
from time import sleep

from container_ci_suite.container_lib import ContainerTestLib, DatabaseWrapper
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS


class TestMySqlReplicationContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        self.replication_db = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.replication_db.set_new_db_type(db_type="mysql")

    def teardown_method(self):
        self.replication_db.cleanup()

    def test_replication(self):
        """ """
        cluster_args = "-e MYSQL_SOURCE_USER=source -e MYSQL_SOURCE_PASSWORD=source -e MYSQL_DATABASE=db"
        source_cid = "source.cid"
        username = "user"
        password = "foo"
        # Run the MySQL source
        assert self.replication_db.create_container(
            cid_file_name=source_cid,
            container_args=[
                f"-e MYSQL_USER={username}",
                f"-e MYSQL_PASSWORD={password}",
                "-e MYSQL_ROOT_PASSWORD=root",
                "-e MYSQL_INNODB_BUFFER_POOL_SIZE=5M",
            ],
            docker_args=cluster_args,
            command="run-mysqld-source",
        )
        source_cip = self.replication_db.get_cip(cid_file_name=source_cid)
        print(f"Source IP: {source_cip}")
        source_cid = self.replication_db.get_cid(cid_file_name=source_cid)
        assert source_cid
        # Run the MySQL replica
        replica_cid = "replica.cid"
        assert self.replication_db.create_container(
            cid_file_name=replica_cid,
            container_args=[
                f"-e MYSQL_SOURCE_SERVICE_NAME={source_cip}",
                "-e MYSQL_INNODB_BUFFER_POOL_SIZE=5M",
            ],
            docker_args=cluster_args,
            command="run-mysqld-replica",
        )
        replica_cip = self.replication_db.get_cip(cid_file_name=replica_cid)
        assert replica_cip
        replica_cid = self.replication_db.get_cid(cid_file_name=replica_cid)
        assert replica_cid
        print(f"Replica IP: {replica_cip}")
        # Now wait till the SOURCE will see the REPLICA
        result = self.replication_db.test_db_connection(
            container_ip=replica_cip,
            username=username,
            password=password,
        )
        result = PodmanCLIWrapper.call_podman_command(
            cmd=f"exec {source_cid} mysql -e 'SHOW REPLICAS;' db",
            ignore_error=True,
            debug=True,
        )
        print(f"Showing replicas: {result}")
        assert replica_cip in result, (
            f"Replica {replica_cip} not found in SOURCE {source_cip}"
        )
        # do some real work to test replication in practice
        result = self.replication_db.test_db_connection(
            container_ip=source_cip,
            username=username,
            password=password,
            max_attempts=120,
            sql_cmd="-e 'CREATE TABLE t1 (a INT); INSERT INTO t1 VALUES (24);'",
        )
        print(f"Creating table: {result}")
        # let's wait for the table to be created and available for replication
        sleep(3)

        result = self.replication_db.test_db_connection(
            container_ip=replica_cip,
            username=username,
            password=password,
            max_attempts=120,
            sql_cmd="-e 'select * from t1;'",
        )
        assert result
        podman_cmd = f"--rm {VARS.IMAGE_NAME} mysql --host {replica_cip} -u{username} -p{password}"
        table_output = PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e 'select * from t1;' db",
        )
        print(f"Selecting from table: {table_output}")
        assert re.search(r"^a\n^24", table_output.strip(), re.MULTILINE), (
            f"Replica {replica_cip} did not get value from SOURCE {source_cip}"
        )
