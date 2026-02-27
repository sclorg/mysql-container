import pytest

from container_ci_suite.openshift import OpenShiftAPI

from conftest import VARS


class TestMySQLDeployTemplate:
    def setup_method(self):
        self.oc_api = OpenShiftAPI(
            pod_name_prefix="mysql-testing", version=VARS.VERSION, shared_cluster=True
        )
        self.oc_api.import_is("imagestreams/mysql-rhel.json", "", skip_check=True)

    def teardown_method(self):
        self.oc_api.delete_project()

    @pytest.mark.parametrize(
        "template", ["mysql-ephemeral-template.json", "mysql-persistent-template.json"]
    )
    def test_template_inside_cluster(self, template):
        short_version = VARS.VERSION.replace(".", "")
        assert self.oc_api.deploy_template_with_image(
            image_name=VARS.IMAGE_NAME,
            template=template,
            name_in_template="mysql",
            openshift_args=[
                f"MYSQL_VERSION={VARS.VERSION}{VARS.TAG}",
                f"DATABASE_SERVICE_NAME={self.oc_api.pod_name_prefix}",
                "MYSQL_USER=testu",
                "MYSQL_PASSWORD=testp",
                "MYSQL_DATABASE=testdb",
            ],
        )

        assert self.oc_api.is_pod_running(pod_name_prefix=self.oc_api.pod_name_prefix)
        assert self.oc_api.check_command_internal(
            image_name=f"registry.redhat.io/{VARS.OS}/mysql-{short_version}",
            service_name=self.oc_api.pod_name_prefix,
            cmd="echo 'SELECT 42 as testval\\g' | mysql --connect-timeout=15 -h <IP> testdb -utestu -ptestp",
            expected_output="42",
        )
