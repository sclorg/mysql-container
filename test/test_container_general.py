import re
import pytest
import tempfile

from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS


class TestMySqlGeneralContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        self.s2i_db = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.s2i_db.set_new_db_type(db_type="mysql")

    def teardown_method(self):
        self.s2i_db.cleanup()

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
        assert self.s2i_db.create_container(
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
        cip = self.s2i_db.get_cip(cid_file_name=cid_file_name)
        assert cip
        assert self.s2i_db.test_db_connection(
            container_ip=cip, username=username, password=password
        )
        cid = self.s2i_db.get_cid(cid_file_name=cid_file_name)
        output = PodmanCLIWrapper.podman_exec_shell_command(
            cid_file_name=cid,
            cmd="mysql --version",
        )
        assert VARS.VERSION in output
        self.s2i_db.db_lib.assert_login_access(
            container_ip=cip,
            username=username,
            password=password,
            expected_success=True,
        )
        self.s2i_db.db_lib.assert_login_access(
            container_ip=cip,
            username=username,
            password=f"{password}_foo",
            expected_success=False,
        )
        if root_password:
            self.s2i_db.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password=root_password,
                expected_success=True,
            )
            self.s2i_db.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password=f"{root_password}_foo",
                expected_success=False,
            )
        else:
            self.s2i_db.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password="foo",
                expected_success=False,
            )
            self.s2i_db.db_lib.assert_login_access(
                container_ip=cip,
                username="root",
                password="",
                expected_success=False,
            )
        output = self.s2i_db.db_lib.assert_local_access(container_id=cid)
        assert output
        podman_cmd = (
            f"--rm {VARS.IMAGE_NAME} mysql --host {cip} -u{username} -p{password}"
        )
        assert PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e 'CREATE TABLE tbl (col1 VARCHAR(20), col2 VARCHAR(20));' db",
        )
        values = 'INSERT INTO tbl VALUES ("foo1", "bar1");'
        assert PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e '{values}' db",
        )
        values = 'INSERT INTO tbl VALUES ("foo2", "bar2");'
        assert PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e '{values}' db",
        )
        values = 'INSERT INTO tbl VALUES ("foo3", "bar3");'
        assert PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e '{values}' db",
        )
        output = PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e 'SELECT * FROM tbl;' db",
        )
        assert re.search(r"foo1\t*bar1", output)
        assert re.search(r"foo2\t*bar2", output)
        assert re.search(r"foo3\t*bar3", output)
        PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e 'DROP TABLE tbl;' db",
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
        assert self.s2i_db.create_container(
            cid_file_name=cid_testupg1,
            container_args=[
                "-e MYSQL_USER=user",
                "-e MYSQL_PASSWORD=foo",
                "-e MYSQL_DATABASE=db",
                f"-v {datadir}/data:/var/lib/mysql/data:Z",
            ],
        )
        cip = self.s2i_db.get_cip(cid_file_name=cid_testupg1)
        assert cip
        assert self.s2i_db.test_db_connection(
            container_ip=cip, username="user", password="foo"
        )
        cid = self.s2i_db.get_cid(cid_file_name=cid_testupg1)
        assert cid
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")

        cid_testupg5 = "testupg5"
        assert self.s2i_db.create_container(
            cid_file_name=cid_testupg5,
            container_args=[
                "-e MYSQL_USER=user",
                "-e MYSQL_PASSWORD=foo",
                "-e MYSQL_DATABASE=db",
                f"-v {datadir}/data:/var/lib/mysql/data:Z",
                "-e MYSQL_DATADIR_ACTION=analyze",
            ],
        )
        cip = self.s2i_db.get_cip(cid_file_name=cid_testupg5)
        assert cip
        assert self.s2i_db.test_db_connection(
            container_ip=cip, username="user", password="foo"
        )
        cid = self.s2i_db.get_cid(cid_file_name=cid_testupg5)
        assert cid
        output = PodmanCLIWrapper.podman_logs(
            container_id=cid,
        )
        assert re.search(r"--analyze --all-databases", output)
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")

        cid_testupg6 = "testupg6"
        assert self.s2i_db.create_container(
            cid_file_name=cid_testupg6,
            container_args=[
                "-e MYSQL_USER=user",
                "-e MYSQL_PASSWORD=foo",
                "-e MYSQL_DATABASE=db",
                f"-v {datadir}/data:/var/lib/mysql/data:Z",
                "-e MYSQL_DATADIR_ACTION=optimize",
            ],
        )
        cip = self.s2i_db.get_cip(cid_file_name=cid_testupg6)
        assert cip
        assert self.s2i_db.test_db_connection(
            container_ip=cip, username="user", password="foo"
        )
        cid = self.s2i_db.get_cid(cid_file_name=cid_testupg6)
        assert cid
        output = PodmanCLIWrapper.podman_logs(
            container_id=cid,
        )
        assert re.search(r"--optimize --all-databases", output)
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
