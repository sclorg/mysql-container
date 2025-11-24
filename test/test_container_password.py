import tempfile

from container_ci_suite.container_lib import ContainerTestLib, DatabaseWrapper
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS


class TestMySqlPasswordContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        self.ssl_db = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.ssl_db.set_new_db_type(db_type="mysql")
        self.db_connector = DatabaseWrapper(image_name=VARS.IMAGE_NAME, db_type="mysql")

    def teardown_method(self):
        self.ssl_db.cleanup()

    def test_password_change(self):
        """ """
        cid_file_name = "test_password_change"
        pwd_dir = tempfile.mkdtemp(prefix="/tmp/mysql-pwd")
        username = "user"
        password = "foo"
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"chmod -R a+rwx {pwd_dir}",
            ]
        )
        assert self.ssl_db.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username}",
                f"-e MYSQL_PASSWORD={password}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        cip = self.ssl_db.get_cip(cid_file_name=cid_file_name)
        assert cip
        assert self.ssl_db.test_db_connection(
            container_ip=cip, username=username, password=password
        )
        cid = self.ssl_db.get_cid(cid_file_name=cid_file_name)
        assert cid
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
        cid_file_name = "test_password_change_2"
        new_password = "bar"
        assert self.ssl_db.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username}",
                f"-e MYSQL_PASSWORD={new_password}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        podman_cmd = (
            f"--rm {VARS.IMAGE_NAME} mysql --host {cip} -u{username} -p{password}"
        )
        output = PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e 'SELECT 1;' db",
        )
        assert output == "1"

    def test_password_change_new_user_test(self):
        """ """
        cid_file_name = "test_password_change1"
        pwd_dir = tempfile.mkdtemp(prefix="/tmp/mysql-pwd")
        username1 = "user"
        password1 = "foo"
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"chmod -R a+rwx {pwd_dir}",
            ]
        )
        assert self.ssl_db.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username1}",
                f"-e MYSQL_PASSWORD={password1}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        cip = self.ssl_db.get_cip(cid_file_name=cid_file_name)
        assert cip
        assert self.ssl_db.test_db_connection(
            container_ip=cip, username=username1, password=password1
        )
        cid = self.ssl_db.get_cid(cid_file_name=cid_file_name)
        assert cid
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
        cid_file_name = "test_password_change2"
        username2 = "user2"
        password2 = "bar"
        # Create second container with changed password
        assert self.ssl_db.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username2}",
                f"-e MYSQL_PASSWORD={password2}",
                "-e MYSQL_DATABASE=db",
                f"-v {pwd_dir}:/var/lib/mysql/data:Z",
            ],
        )
        cip2 = self.ssl_db.get_cip(cid_file_name=cid_file_name)
        assert cip2
        assert self.ssl_db.test_db_connection(
            container_ip=cip2, username=username1, password=password1
        )
        cid2 = self.ssl_db.get_cid(cid_file_name=cid_file_name)
        mysql_logs = PodmanCLIWrapper.podman_logs(
            conatiner_id=cid2,
        )
        assert "User user2 does not exist in database" in mysql_logs
        podman_cmd = (
            f"--rm {VARS.IMAGE_NAME} mysql --host {cip2} -u{username1} -p{password2}"
        )
        output = PodmanCLIWrapper.podman_run_command(
            cmd=f"{podman_cmd} -e 'SELECT 1;' db",
        )
        assert output == "1"
