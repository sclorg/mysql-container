import tempfile
import pytest

from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.database import DatabaseWrapper
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS

pwd_dir_change = tempfile.mkdtemp(prefix="/tmp/mysql-pwd")
assert ContainerTestLibUtils.commands_to_run(
    commands_to_run=[
        f"chmod -R a+rwx {pwd_dir_change}",
    ]
)

user_dir_change = tempfile.mkdtemp(prefix="/tmp/mysql-user")
assert ContainerTestLibUtils.commands_to_run(
    commands_to_run=[
        f"chmod -R a+rwx {user_dir_change}",
    ]
)


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

    @pytest.mark.parametrize(
        "username, password, pwd_change, user_change, test_dir",
        [
            ("user", "foo", False, False, pwd_dir_change),
            ("user", "bar", True, False, pwd_dir_change),
            ("user", "foo", False, False, user_dir_change),
            ("user2", "bar", False, True, user_dir_change),
        ],
    )
    def test_password_change(
        self, username, password, pwd_change, user_change, test_dir
    ):
        """
        Test password change.
        """
        self.password_change_test(
            username=username,
            password=password,
            pwd_dir=test_dir,
            user_change=user_change,
            pwd_change=pwd_change,
        )

    def password_change_test(
        self, username, password, pwd_dir, user_change=False, pwd_change=False
    ):
        """
        Test password change.
        Steps are:
        1. Create a container with the given arguments
        2. Check if the container is created successfully
        3. Check if the database connection works
        4. If user_change is True, then 'user' and 'foo' are used for testing connection
        4. Check if the userchange, then user2 does exist in the database logs
        5. Check if the userchange, then sql command should work with the 'user' and 'bar' should
        not work and should return an error message
        6. If pwd_change is True, then 'user' and 'pwdfoo' should not work and should return an error message
        """
        cid_file_name = f"test_{username}_{password}_{user_change}"

        container_args = [
            f"-e MYSQL_USER={username}",
            f"-e MYSQL_PASSWORD={password}",
            "-e MYSQL_DATABASE=db",
            f"-v {pwd_dir}:/var/lib/mysql/data:Z",
        ]
        assert self.pwd_change.create_container(
            cid_file_name=cid_file_name,
            container_args=container_args,
        )
        cip, cid = self.pwd_change.get_cip_cid(cid_file_name=cid_file_name)
        assert cip, cid
        if user_change:
            username = "user"
            password = "foo"
        # Test if the database connection works with the old connection parameters
        assert self.pwd_change.test_db_connection(
            container_ip=cip,
            username=username,
            password=password,
        )
        if user_change:
            mariadb_logs = PodmanCLIWrapper.podman_logs(
                container_id=cid,
            )
            assert "User user2 does not exist in database" in mariadb_logs
            username = "user"
            password = "bar"
            output = self.dw_api.run_sql_command(
                container_ip=cip,
                username=username,
                password=password,
                container_id=VARS.IMAGE_NAME,
                ignore_error=True,
            )
            assert f"Access denied for user '{username}'@" in output, (
                f"The new password {password} should not work, but it does"
            )
        if pwd_change:
            output = self.dw_api.run_sql_command(
                container_ip=cip,
                username=username,
                password="pwdfoo",
                container_id=VARS.IMAGE_NAME,
                ignore_error=True,
            )
            assert f"Access denied for user '{username}'@" in output, (
                f"The old password {password} should not work, but it does"
            )
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
