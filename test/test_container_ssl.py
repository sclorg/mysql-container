import tempfile
import re

from container_ci_suite.container_lib import ContainerTestLib
from container_ci_suite.container_lib import ContainerTestLibUtils
from container_ci_suite.engines.podman_wrapper import PodmanCLIWrapper

from conftest import VARS


class TestMySqlGeneralContainer:
    """
    Test MySQL container configuration.
    """

    def setup_method(self):
        self.ssl_db = ContainerTestLib(image_name=VARS.IMAGE_NAME)
        self.ssl_db.set_new_db_type(db_type="mysql")

    def teardown_method(self):
        self.ssl_db.cleanup()

    def test_ssl(self):
        """ """
        ssl_dir = tempfile.mkdtemp(prefix="/tmp/mysql-ssl_data")
        username = "ssl_test_user"
        password = "ssl_test"
        with open(f"{ssl_dir}/ssl.cnf", mode="wt+") as f:
            lines = [
                "[mysqld]",
                "ssl-key=${APP_DATA}/mysql-certs/server-key.pem",
                "ssl-cert=${APP_DATA}/mysql-certs/server-cert-selfsigned.pem",
            ]
            f.write("\n".join(lines))
        srv_key_pem = f"{ssl_dir}/server-key.pem"
        srv_req_pem = f"{ssl_dir}/server-req.pem"
        srv_self_pem = f"{ssl_dir}/server-cert-selfsigned.pem"
        openssl_cmd = "openssl req -newkey rsa:2048 -nodes"
        openssl_cmd_new = "openssl req -new -x509 -nodes"
        subj = "/C=GB/ST=Berkshire/L=Newbury/O=My Server Company"
        ContainerTestLibUtils.run_command(
            cmd=f"{openssl_cmd} -keyout {srv_key_pem} -subj '{subj}' > {srv_req_pem}"
        )
        ContainerTestLibUtils.run_command(
            cmd=f"{openssl_cmd_new} -key {srv_key_pem} -batch > {srv_self_pem}"
        )
        assert ContainerTestLibUtils.commands_to_run(
            commands_to_run=[
                f"mkdir -p {ssl_dir}/mysql-certs {ssl_dir}/mysql-cfg",
                f"cp {ssl_dir}/server-cert-selfsigned.pem {ssl_dir}/mysql-certs/server-cert-selfsigned.pem",
                f"cp {ssl_dir}/server-key.pem {ssl_dir}/mysql-certs/server-key.pem",
                f"cp {ssl_dir}/ssl.cnf {ssl_dir}/mysql-cfg/ssl.cnf",
                f"chown -R 27:27 {ssl_dir}",
            ]
        )

        ca_cert_path = "/opt/app-root/src/mysql-certs/server-cert-selfsigned.pem"
        cid_file_name = "s2i_test_ssl"
        assert self.ssl_db.create_container(
            cid_file_name=cid_file_name,
            container_args=[
                f"-e MYSQL_USER={username}",
                f"-e MYSQL_PASSWORD={password}",
                "-e MYSQL_DATABASE=db",
                f"-v {ssl_dir}:/opt/app-root/src/:z",
            ],
        )
        cip = self.ssl_db.get_cip(cid_file_name=cid_file_name)
        assert cip
        assert self.ssl_db.test_db_connection(
            container_ip=cip, username=username, password=password
        )
        cid = self.ssl_db.get_cid(cid_file_name=cid_file_name)
        assert cid

        mysql_cmd = (
            f"mysql --host {cip} -u{username} -p{password} --ssl-ca={ca_cert_path}"
            + " -e 'show status like \"Ssl_cipher\" \\G' db"
        )
        ssl_output = PodmanCLIWrapper.podman_run_command(
            cmd=f"--rm -v {ssl_dir}:/opt/app-root/src/:z {VARS.IMAGE_NAME} {mysql_cmd}",
        )
        assert re.search(r"Value: [A-Z][A-Z0-9-]*", ssl_output)
