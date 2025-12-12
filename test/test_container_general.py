import re
import pytest
import tempfile

from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.database import DatabaseWrapper
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS


class TestMySqlGeneralContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        self.db_image = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.db_image.set_new_db_type(db_type="mysql")
        self.db_api = DatabaseWrapper(image_name=VARS.IMAGE_NAME)

    def teardown_method(self):
        self.db_image.cleanup()

    @pytest.mark.parametrize(
        "docker_args, username, password, root_password",
        [
            ("", "user", "pass", ""),
            ("", "user1", "pass1", "r00t"),
            ("--user 12345", "user", "pass", ""),
            ("--user 12345", "user1", "pass1", "r00t"),
        ],
    )
    def test_run(self, docker_args, username, password, root_password):
        """
        Test container creation fails with invalid combinations of arguments.
        """
        root_password_arg = (
            f"-e MYSQL_ROOT_PASSWORD={root_password}" if root_password else ""
        )
        cid_file_name = f"test_{username}_{password}_{root_password}"
        assert self.db_image.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username}",
                f"-e MYSQL_PASSWORD={password}",
                "-e MYSQL_DATABASE=db",
                f"{root_password_arg}",
                f"{docker_args}",
            ],
            command="run-mysqld --innodb_buffer_pool_size=5242880",
        )
        cip = self.db_image.get_cip(cid_file_name=cid_file_name)
        assert cip
        assert self.db_image.test_db_connection(
            container_ip=cip, username=username, password=password
        )
        cid = self.db_image.get_cid(cid_file_name=cid_file_name)
        output = PodmanCLIWrapper.podman_exec_shell_command(
            cid_file_name=cid,
            cmd="mysql --version",
        )
        assert VARS.VERSION in output
        self.db_image.db_lib.assert_login_access(
            container_ip=cip,
            username=username,
            password=password,
            expected_success=True,
        )
        self.db_image.db_lib.assert_login_access(
            container_ip=cip,
            username=username,
            password=f"{password}_foo",
            expected_success=False,
        )
        if root_password:
            self.db_image.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password=root_password,
                expected_success=True,
            )
            self.db_image.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password=f"{root_password}_foo",
                expected_success=False,
            )
        else:
            self.db_image.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password="foo",
                expected_success=False,
            )
            self.db_image.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password="",
                expected_success=False,
            )
        assert self.db_image.db_lib.assert_local_access(container_id=cid)
        self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            sql_cmd=[
                "CREATE TABLE tbl (col1 VARCHAR(20), col2 VARCHAR(20));",
            ],
        )
        self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            sql_cmd=[
                'INSERT INTO tbl VALUES ("foo1", "bar1");',
                'INSERT INTO tbl VALUES ("foo2", "bar2");',
                'INSERT INTO tbl VALUES ("foo3", "bar3");',
            ],
        )
        output = self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            sql_cmd="SELECT * FROM tbl;",
        )
        words = [
            "foo1\t*bar1",
            "foo2\t*bar2",
            "foo3\t*bar3",
        ]
        for word in words:
            assert re.search(word, output), f"Word {word} not found in {output}"
        self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            sql_cmd="DROP TABLE tbl;",
        )

    def test_datadir_actions(self):
        """
        Test container creation fails with invalid combinations of arguments.
        """
        cid_testupg1 = "testupg1"
        datadir = tempfile.mkdtemp(prefix="/tmp/mysql-datadir-actions")
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"mkdir -p {datadir}/data",
                f"chmod -R a+rwx {datadir}",
            ]
        )
        mysql_user = "user"
        mysql_password = "foo"
        mysql_database = "db"
        assert self.db_image.create_container(
            cid_file_name=cid_testupg1,
            container_args=[
                f"-e MYSQL_USER={mysql_user}",
                f"-e MYSQL_PASSWORD={mysql_password}",
                f"-e MYSQL_DATABASE={mysql_database}",
                f"-v {datadir}/data:/var/lib/mysql/data:Z",
            ],
        )
        cip = self.db_image.get_cip(cid_file_name=cid_testupg1)
        assert cip
        assert self.db_image.test_db_connection(
            container_ip=cip, username="user", password="foo"
        )
        cid = self.db_image.get_cid(cid_file_name=cid_testupg1)
        assert cid
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")

        cid_testupg5 = "testupg5"
        assert self.db_image.create_container(
            cid_file_name=cid_testupg5,
            container_args=[
                f"-e MYSQL_USER={mysql_user}",
                f"-e MYSQL_PASSWORD={mysql_password}",
                f"-e MYSQL_DATABASE={mysql_database}",
                f"-v {datadir}/data:/var/lib/mysql/data:Z",
                "-e MYSQL_DATADIR_ACTION=analyze",
            ],
        )
        cip = self.db_image.get_cip(cid_file_name=cid_testupg5)
        assert cip
        assert self.db_image.test_db_connection(
            container_ip=cip, username=mysql_user, password=mysql_password
        )
        cid = self.db_image.get_cid(cid_file_name=cid_testupg5)
        assert cid
        output = PodmanCLIWrapper.podman_logs(
            container_id=cid,
        )
        assert re.search(r"--analyze --all-databases", output)
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")

        cid_testupg6 = "testupg6"
        assert self.db_image.create_container(
            cid_file_name=cid_testupg6,
            container_args=[
                f"-e MYSQL_USER={mysql_user}",
                f"-e MYSQL_PASSWORD={mysql_password}",
                f"-e MYSQL_DATABASE={mysql_database}",
                f"-v {datadir}/data:/var/lib/mysql/data:Z",
                "-e MYSQL_DATADIR_ACTION=optimize",
            ],
        )
        cip = self.db_image.get_cip(cid_file_name=cid_testupg6)
        assert cip
        assert self.db_image.test_db_connection(
            container_ip=cip, username=mysql_user, password=mysql_password
        )
        cid = self.db_image.get_cid(cid_file_name=cid_testupg6)
        assert cid
        output = PodmanCLIWrapper.podman_logs(
            container_id=cid,
        )
        assert re.search(r"--optimize --all-databases", output)
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
