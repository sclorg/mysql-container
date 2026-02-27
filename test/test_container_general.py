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
        """
        Setup the test environment.
        """
        self.db_image = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.db_image.set_new_db_type(db_type="mysql")
        self.db_api = DatabaseWrapper(image_name=VARS.IMAGE_NAME)

    def teardown_method(self):
        """
        Teardown the test environment.
        """
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
        Test if the MySQL container works properly with the different arguments
        like docker_args, username, password, and root_password.
        Steps are:
        1. Create a container with the given arguments
        2. Check if the container is created successfully
        3. Check if the database connection works
        4. Check if mariadb version is correct
        5. Check if the login access works
        6. Check if the local access works
        7. Test the database creation
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
        cip, cid = self.db_image.get_cip_cid(cid_file_name=cid_file_name)
        assert cip, cid
        assert self.db_image.test_db_connection(
            container_ip=cip, username=username, password=password
        )
        output = PodmanCLIWrapper.podman_exec_shell_command(
            cid_file_name=cid,
            cmd="mysql --version",
        )
        assert VARS.VERSION in output
        login_access = True
        for user, pwd, ret_value in [
            (username, password, True),
            (username, f"{password}_foo", False),
            ("root", "foo", False),
            ("root", "", False),
        ]:
            test_assert = self.db_image.db_lib.assert_login_access(
                container_ip=cip,
                username=user,
                password=pwd,
                expected_success=ret_value,
            )
            if not test_assert:
                print(
                    f"Login access failed for {user}:{pwd} with expected success {ret_value}"
                )
                login_access = False
        assert login_access
        if root_password:
            root_login_access = True
            for user, pwd, ret_value in [
                ("root", root_password, True),
                ("root", f"{root_password}_foo", False),
            ]:
                test_assert = self.db_image.db_lib.assert_login_access(
                    container_ip=cip,
                    username=user,
                    password=pwd,
                    expected_success=ret_value,
                )
                if not test_assert:
                    print(
                        f"Root login access failed for {user}:{pwd} with expected success {ret_value}"
                    )
                    root_login_access = False
                    continue
            assert root_login_access
        assert self.db_image.db_lib.assert_local_access(container_id=cid)
        self.database_test(cip, username, password)

    def database_test(self, cip, username, password):
        """
        Test MariaDB database table creation and data insertion is valid.
        """
        self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            sql_cmd=[
                "CREATE TABLE tbl (a integer, b integer);",
            ],
        )
        self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            sql_cmd=[
                "INSERT INTO tbl VALUES (1, 2);",
                "INSERT INTO tbl VALUES (3, 4);",
                "INSERT INTO tbl VALUES (5, 6);",
            ],
        )
        output = self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            sql_cmd="SELECT * FROM tbl;",
        )
        expected_db_output = [
            r"1\s*\t*2",
            r"3\s*\t*4",
            r"5\s*\t*6",
        ]
        for row in expected_db_output:
            assert re.search(row, output), f"Row {row} not found in {output}"
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
        cip, cid = self.db_image.get_cip_cid(cid_file_name=cid_testupg1)
        assert cip, cid
        assert self.db_image.test_db_connection(
            container_ip=cip, username="user", password="foo"
        )
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
        cip, cid = self.db_image.get_cip_cid(cid_file_name=cid_testupg5)
        assert cip, cid
        assert self.db_image.test_db_connection(
            container_ip=cip, username=mysql_user, password=mysql_password
        )
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
        cip, cid = self.db_image.get_cip_cid(cid_file_name=cid_testupg6)
        assert cip, cid
        assert self.db_image.test_db_connection(
            container_ip=cip, username=mysql_user, password=mysql_password
        )
        output = PodmanCLIWrapper.podman_logs(
            container_id=cid,
        )
        assert re.search(r"--optimize --all-databases", output)
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
