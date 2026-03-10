import shutil
import tempfile

from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper
from pathlib import Path

from conftest import VARS


def build_s2i_app(app_path: Path) -> ContainerTestLib:
    container_lib = ContainerTestLib(VARS.IMAGE_NAME)
    app_name = app_path.name
    s2i_app = container_lib.build_as_df(
        app_path=app_path,
        s2i_args="--pull-policy=never",
        src_image=VARS.IMAGE_NAME,
        dst_image=f"{VARS.IMAGE_NAME}-{app_name}",
    )
    return s2i_app


class TestMySqlBasicsContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        """
        Setup the test environment.
        """
        self.app_image = build_s2i_app(app_path=VARS.TEST_APP)
        self.app_image.set_new_db_type(db_type="mysql")

    def teardown_method(self):
        """
        Teardown the test environment.
        """
        self.app_image.cleanup()

    def test_connection_without_mount(self):
        """
        Test if MySQL container failed in case of invalid combinations.
        Steps are:
        1. Test if the container creation fails with invalid combinations of arguments
        2. Test if the container creation succeeds with valid combinations of arguments
        3. Test if the database connection works
        """
        cid_mount = "connection_without_mount"
        self.app_image.assert_container_creation_fails(
            cid_file_name=cid_mount,
            command="",
            container_args=[
                "-e MYSQL_USER=root",
                "-e MYSQL_PASSWORD=pass",
                "-e MYSQL_DATABASE=db",
                "-e MYSQL_ROOT_PASSWORD=pass",
            ],
        )
        operation_user = "operations_user"
        operation_pass = "operations_pass"
        assert self.app_image.create_container(
            cid_file_name=cid_mount,
            container_args=[
                "-e MYSQL_USER=config_test_user",
                "-e MYSQL_PASSWORD=config_test_user",
                "-e MYSQL_DATABASE=db",
                f"-e MYSQL_OPERATIONS_USER={operation_user}",
                f"-e MYSQL_OPERATIONS_PASSWORD={operation_pass}",
            ],
        )
        cip, cid = self.app_image.get_cip_cid(cid_file_name=cid_mount)
        assert cip and cid
        assert self.app_image.test_db_connection(
            container_ip=cip, username=operation_user, password=operation_pass
        )
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")

    def test_connection_with_mount(self):
        """
        Test if the MySQL container works properly with mounted application directory.
        Steps are:
        1. Copy the test-app directory to a temporary directory and set proper permissions
        2. Create a container with the mounted directory
        3. Test if the database connection works with the operations user
        """
        data_dir = tempfile.mkdtemp(prefix="/tmp/mysql-test_data")
        shutil.copytree(VARS.TEST_APP, f"{data_dir}/test-app")
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"chown -R 27:27 {data_dir}/test-app",
            ]
        )
        cid_with_mount = "connection_with_mount"
        operation_user = "operations_user"
        operation_pass = "operations_pass"

        self.app_image.create_container(
            cid_file_name=cid_with_mount,
            container_args=[
                "-e MYSQL_USER=config_test_user",
                "-e MYSQL_PASSWORD=config_test_user",
                "-e MYSQL_DATABASE=db",
                f"-e MYSQL_OPERATIONS_USER={operation_user}",
                f"-e MYSQL_OPERATIONS_PASSWORD={operation_pass}",
                f"-v {data_dir}/test-app:/opt/app-root/src/:z",
            ],
        )
        cip, cid = self.app_image.get_cip_cid(cid_file_name=cid_with_mount)
        assert cip and cid
        assert self.app_image.test_db_connection(
            container_ip=cip,
            username=operation_user,
            password=operation_pass,
            max_attempts=10,
        )
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
        shutil.rmtree(data_dir)
