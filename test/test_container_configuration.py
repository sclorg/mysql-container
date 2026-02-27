import re

import pytest

from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.engines.database import DatabaseWrapper
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS


class TestMySqlConfigurationContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.db = ContainerTestLib(image_name=VARS.IMAGE_NAME)

    def teardown_method(self):
        """
        Teardown the test environment.
        """
        self.db.cleanup()

    def test_container_creation_fails(self):
        """
        Test container creation fails with no arguments.
        """
        cid_config_test = "container_creation_fails"
        assert self.db.assert_container_creation_fails(
            cid_file_name=cid_config_test, container_args=[], command=""
        )

    @pytest.mark.parametrize(
        "container_args",
        [
            ["-e MYSQL_USER=user", "-e MYSQL_DATABASE=db"],
            ["-e MYSQL_PASSWORD=pass", "-e MYSQL_DATABASE=db"],
        ],
    )
    def test_try_image_invalid_combinations(self, container_args):
        """
        Test container creation fails with invalid combinations of arguments.
        """
        cid_file_name = "try_image_invalid_combinations"
        assert self.db.assert_container_creation_fails(
            cid_file_name=cid_file_name, container_args=container_args, command=""
        )

    @pytest.mark.parametrize(
        "mysql_user, mysql_password, mysql_database, mysql_root_password",
        [
            ["user", "pass", "", ""],
            [
                "$invalid",
                "pass",
                "db",
                "root_pass",
            ],
            [
                VARS.VERY_LONG_USER_NAME,
                "pass",
                "db",
                "root_pass",
            ],
            [
                "user",
                "",
                "db",
                "root_pass",
            ],
            [
                "user",
                "pass",
                "$invalid",
                "root_pass",
            ],
            [
                "user",
                "pass",
                VARS.VERY_LONG_DB_NAME,
                "root_pass",
            ],
            [
                "user",
                "pass",
                "db",
                "",
            ],
            [
                "root",
                "pass",
                "db",
                "pass",
            ],
        ],
    )
    def test_invalid_configuration_tests(
        self, mysql_user, mysql_password, mysql_database, mysql_root_password
    ):
        """
        Test invalid configuration combinations for MySQL container.
        """
        cid_config_test = "invalid_configuration_tests"
        mysql_user_arg = f"-e MYSQL_USER={mysql_user}" if mysql_user else ""
        mysql_password_arg = (
            f"-e MYSQL_PASSWORD={mysql_password}" if mysql_password else ""
        )
        mysql_database_arg = (
            f"-e MYSQL_DATABASE={mysql_database}" if mysql_database else ""
        )
        mysql_root_password_arg = (
            f"-e MYSQL_ROOT_PASSWORD={mysql_root_password}"
            if mysql_root_password
            else ""
        )
        assert self.db.assert_container_creation_fails(
            cid_file_name=cid_config_test,
            container_args=[
                mysql_user_arg,
                mysql_password_arg,
                mysql_database_arg,
                mysql_root_password_arg,
            ],
            command="",
        )


class TestMySqlConfigurationTests:
    """
    Test MySQL container configuration tests.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.db_config = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.db_api = DatabaseWrapper(image_name=VARS.IMAGE_NAME)

    def teardown_method(self):
        """
        Teardown the test environment.
        """
        self.db_config.cleanup()

    def test_configuration_auto_calculated_settings(self):
        """
        Test MySQL container configuration auto-calculated settings.
        Steps are:
        1. Create a container with the given arguments
        2. Check if the container is created successfully
        3. Check if the database connection works
        4. Check if the database configurations are correct
        5. Stop the container
        """
        cid_config_test = "auto-config_test"
        username = "config_test_user"
        password = "config_test"
        assert self.db_config.create_container(
            cid_file_name=cid_config_test,
            container_args=[
                "--env MYSQL_COLLATION=latin2_czech_cs",
                "--env MYSQL_CHARSET=latin2",
                f"--env MYSQL_USER={username}",
                f"--env MYSQL_PASSWORD={password}",
                "--env MYSQL_DATABASE=db",
            ],
            docker_args="--memory=512m",
        )
        cip, cid = self.db_config.get_cip_cid(cid_file_name=cid_config_test)
        assert cip, cid
        assert self.db_config.test_db_connection(
            container_ip=cip,
            username=username,
            password=password,
            max_attempts=10,
        )
        db_configuration = PodmanCLIWrapper.podman_exec_shell_command(
            cid_file_name=cid,
            cmd="cat /etc/my.cnf /etc/my.cnf.d/*",
        )
        expected_values = [
            r"key_buffer_size\s*=\s*51M",
            r"read_buffer_size\s*=\s*25M",
            r"innodb_buffer_pool_size\s*=\s*256M",
            r"innodb_log_file_size\s*=\s*76M",
            r"innodb_log_buffer_size\s*=\s*76M",
            r"authentication_policy\s*=\s*'caching_sha2_password,,'",
        ]
        for value in expected_values:
            assert re.search(value, db_configuration), (
                f"Expected value {value} not found in {db_configuration}"
            )
        # do some real work to test replication in practice
        self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=cid,
            sql_cmd="CREATE TABLE tbl (col VARCHAR(20));",
            podman_run_command="exec",
        )
        show_table_output = self.db_api.run_sql_command(
            container_ip=cip,
            username=username,
            password=password,
            container_id=cid,
            sql_cmd="SHOW CREATE TABLE tbl;",
            podman_run_command="exec",
        )
        assert "CHARSET=latin2" in show_table_output
        assert "COLLATE=latin2_czech_cs" in show_table_output
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")

    # FIX
    def test_configuration_options_settings(self):
        """
        Test MySQL container configuration options.
        """
        cid_config_test = "config_test"
        username = "config_test_user"
        password = "config_test"
        assert self.db_config.create_container(
            cid_file_name=cid_config_test,
            container_args=[
                f"--env MYSQL_USER={username}",
                f"--env MYSQL_PASSWORD={password}",
                "--env MYSQL_DATABASE=db",
                "--env MYSQL_LOWER_CASE_TABLE_NAMES=1",
                "--env MYSQL_LOG_QUERIES_ENABLED=1",
                "--env MYSQL_MAX_CONNECTIONS=1337",
                "--env MYSQL_FT_MIN_WORD_LEN=8",
                "--env MYSQL_FT_MAX_WORD_LEN=15",
                "--env MYSQL_MAX_ALLOWED_PACKET=10M",
                "--env MYSQL_TABLE_OPEN_CACHE=100",
                "--env MYSQL_SORT_BUFFER_SIZE=256K",
                "--env MYSQL_KEY_BUFFER_SIZE=16M",
                "--env MYSQL_READ_BUFFER_SIZE=16M",
                "--env MYSQL_INNODB_BUFFER_POOL_SIZE=16M",
                "--env MYSQL_INNODB_LOG_FILE_SIZE=4M",
                "--env MYSQL_INNODB_LOG_BUFFER_SIZE=4M",
                "--env MYSQL_AUTHENTICATION_POLICY=sha256_password,,",
                "--env WORKAROUND_DOCKER_BUG_14203=",
            ],
        )
        cip, cid = self.db_config.get_cip_cid(cid_file_name=cid_config_test)
        assert cip, cid
        assert self.db_config.test_db_connection(
            container_ip=cip,
            username=username,
            password=password,
            max_attempts=10,
        )
        db_configuration = PodmanCLIWrapper.podman_exec_shell_command(
            cid_file_name=cid,
            cmd="cat /etc/my.cnf /etc/my.cnf.d/*",
        )
        expected_values = [
            r"lower_case_table_names\s*=\s*1",
            r"general_log\s*=\s*1",
            r"max_connections\s*=\s*1337",
            r"ft_min_word_len\s*=\s*8",
            r"ft_max_word_len\s*=\s*15",
            r"max_allowed_packet\s*=\s*10M",
            r"table_open_cache\s*=\s*100",
            r"sort_buffer_size\s*=\s*256K",
            r"key_buffer_size\s*=\s*16M",
            r"read_buffer_size\s*=\s*16M",
            r"innodb_log_file_size\s*=\s*4M",
            r"innodb_log_buffer_size\s*=\s*4M",
            r"authentication_policy\s*=\s*'sha256_password,,'",
        ]
        for value in expected_values:
            assert re.search(value, db_configuration), (
                f"Expected value {value} not found in {db_configuration}"
            )
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
