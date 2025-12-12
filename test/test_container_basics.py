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
        self.s2i_db = build_s2i_app(app_path=VARS.TEST_DIR / "test-app")
        self.s2i_db.set_new_db_type(db_type="mysql")

    def teardown_method(self):
        self.s2i_db.cleanup()

    def test_s2i_usage(self):
        """
        Test container creation fails with invalid combinations of arguments.
        """
        cid_config_build = "s2i_config_build"
        self.s2i_db.assert_container_creation_fails(
            cid_file_name=cid_config_build,
            command="",
            container_args=[
                "-e MYSQL_USER=root",
                "-e MYSQL_PASSWORD=pass",
                "-e MYSQL_DATABASE=db",
                "-e MYSQL_ROOT_PASSWORD=pass",
            ],
        )
        assert self.s2i_db.create_container(
            cid_file_name=cid_config_build,
            container_args=[
                "-e MYSQL_USER=config_test_user",
                "-e MYSQL_PASSWORD=config_test_user",
                "-e MYSQL_DATABASE=db",
                "-e MYSQL_OPERATIONS_USER=operations_user",
                "-e MYSQL_OPERATIONS_PASSWORD=operations_user",
            ],
        )
        cip = self.s2i_db.get_cip(cid_file_name=cid_config_build)
        assert cip
        assert self.s2i_db.test_db_connection(
            container_ip=cip, username="operations_user", password="operations_user"
        )
        cid = self.s2i_db.get_cid(cid_file_name=cid_config_build)
        db_configuration = PodmanCLIWrapper.podman_exec_shell_command(
            cid_file_name=cid,
            cmd="cat /etc/my.cnf /etc/my.cnf.d/*",
        )
        assert db_configuration
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")

    def test_s2i_usage_with_mount(self):
        """
        Test container creation fails with invalid combinations of arguments.
        """
        data_dir = tempfile.mkdtemp(prefix="/tmp/mysql-test_data")
        shutil.copytree(VARS.TEST_DIR / "test-app", f"{data_dir}/test-app")
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"chown -R 27:27 {data_dir}/test-app",
            ]
        )
        cid_s2i_test_mount = "s2i_test_mount"
        self.s2i_db.create_container(
            cid_file_name=cid_s2i_test_mount,
            container_args=[
                "-e MYSQL_USER=config_test_user",
                "-e MYSQL_PASSWORD=config_test_user",
                "-e MYSQL_DATABASE=db",
                "-e MYSQL_OPERATIONS_USER=operations_user",
                "-e MYSQL_OPERATIONS_PASSWORD=operations_pass",
                f"-v {data_dir}/test-app:/opt/app-root/src/:z",
            ],
        )
        cip_test_mount = self.s2i_db.get_cip(cid_file_name=cid_s2i_test_mount)
        assert cip_test_mount
        assert self.s2i_db.test_db_connection(
            container_ip=cip_test_mount,
            username="operations_user",
            password="operations_pass",
            max_attempts=10,
        )
        cid = self.s2i_db.get_cid(cid_file_name=cid_s2i_test_mount)
        assert cid
        PodmanCLIWrapper.call_podman_command(cmd=f"stop {cid}")
        shutil.rmtree(data_dir)
