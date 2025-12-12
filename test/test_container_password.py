import tempfile

from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.database import DatabaseWrapper
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS


class TestMySqlPasswordContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.pwd_change = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.pwd_change.set_new_db_type(db_type="mysql")
        self.dw_api = DatabaseWrapper(image_name=VARS.IMAGE_NAME)

    def teardown_method(self):
        """
        Teardown the test environment.
        """
        self.pwd_change.cleanup()

    def test_password_change(self):
        """
        Test password change.
        """
        cid_file_name1 = "test_password_change"
        pwd_dir = tempfile.mkdtemp(prefix="/tmp/mysql-pwd")
        username = "user"
        password = "foo"
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"chmod -R a+rwx {pwd_dir}",
            ]
        )
        assert self.pwd_change.create_container(
            cid_file_name=cid_file_name1,
            container_args=[
                f"-e MYSQL_USER={username}",
                f"-e MYSQL_PASSWORD={password}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        cip1 = self.pwd_change.get_cip(cid_file_name=cid_file_name1)
        assert cip1
        assert self.pwd_change.test_db_connection(
            container_ip=cip1, username=username, password=password
        )
        cid1 = self.pwd_change.get_cid(cid_file_name=cid_file_name1)
        assert cid1
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid1}")
        cid_file_name2 = "test_password_change_2"
        new_password = "bar"
        assert self.pwd_change.create_container(
            cid_file_name=cid_file_name2,
            container_args=[
                f"-e MYSQL_USER={username}",
                f"-e MYSQL_PASSWORD={new_password}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        cip2 = self.pwd_change.get_cip(cid_file_name=cid_file_name2)
        assert cip2
        assert self.pwd_change.test_db_connection(
            container_ip=cip2, username=username, password=new_password
        )
        output = self.dw_api.run_sql_command(
            container_ip=cip2,
            username=username,
            password=password,
            container_id=VARS.IMAGE_NAME,
            ignore_error=True,
        )
        assert f"Access denied for user '{username}'@" in output, (
            f"The old password {password} should not work, but it does"
        )

    def test_password_change_new_user_test(self):
        """
        Test password change for new user.
        """
        cid_file_name = "test_password_change1"
        pwd_dir = tempfile.mkdtemp(prefix="/tmp/mysql-pwd")
        username1 = "user"
        password1 = "foo"
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"chmod -R a+rwx {pwd_dir}",
            ]
        )
        assert self.pwd_change.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username1}",
                f"-e MYSQL_PASSWORD={password1}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        cip1 = self.pwd_change.get_cip(cid_file_name=cid_file_name)
        assert cip1
        assert self.pwd_change.test_db_connection(
            container_ip=cip1, username=username1, password=password1
        )
        cid = self.pwd_change.get_cid(cid_file_name=cid_file_name)
        assert cid
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
        cid_file_name = "test_password_change2"
        username2 = "user2"
        password2 = "bar"
        # Create second container with changed password
        assert self.pwd_change.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username2}",
                f"-e MYSQL_PASSWORD={password2}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        cip2 = self.pwd_change.get_cip(cid_file_name=cid_file_name)
        assert cip2
        assert self.pwd_change.test_db_connection(
            container_ip=cip2, username=username1, password=password1
        )
        cid2 = self.pwd_change.get_cid(cid_file_name=cid_file_name)
        mysql_logs = PodmanCLIWrapper.podman_logs(
            container_id=cid2,
        )
        assert "User user2 does not exist in database" in mysql_logs
        output = self.dw_api.run_sql_command(
            container_ip=cip2,
            username=username1,
            password=password2,
            container_id=VARS.IMAGE_NAME,
            ignore_error=True,
        )
        assert f"Access denied for user '{username1}'@" in output, (
            f"The new password {password2} should not work, but it does"
        )
