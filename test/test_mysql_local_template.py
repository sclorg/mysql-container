import os
import sys

import pytest

from container_ci_suite.openshift import OpenShiftAPI
from container_ci_suite.utils import check_variables

if not check_variables():
    print("At least one variable from IMAGE_NAME, OS, VERSION is missing.")
    sys.exit(1)


VERSION = os.getenv("VERSION")
IMAGE_NAME = os.getenv("IMAGE_NAME")
OS = os.getenv("TARGET")

TAGS = {
    "rhel8": "-el8",
    "rhel9": "-el9"
}
TAG = TAGS.get(OS, None)


class TestMySQLDeployTemplate:

    def setup_method(self):
        self.oc_api = OpenShiftAPI(pod_name_prefix="mysql-testing", version=VERSION)
        self.oc_api.import_is("imagestreams/mysql-rhel.json", "", skip_check=True)

    def teardown_method(self):
        self.oc_api.delete_project()

    @pytest.mark.parametrize(
        "template",
        [
            "mysql-ephemeral-template.json",
            "mysql-persistent-template.json"
        ]
    )
    def test_template_inside_cluster(self, template):
        short_version = VERSION.replace(".", "")
        assert self.oc_api.deploy_template_with_image(
            image_name=IMAGE_NAME,
            template=template,
            name_in_template="mysql",
            openshift_args=[
                f"MYSQL_VERSION={VERSION}{TAG}",
                f"DATABASE_SERVICE_NAME={self.oc_api.pod_name_prefix}",
                f"MYSQL_USER=testu",
                f"MYSQL_PASSWORD=testp",
                f"MYSQL_DATABASE=testdb"
            ]
        )

        assert self.oc_api.is_pod_running(pod_name_prefix=self.oc_api.pod_name_prefix)
        assert self.oc_api.check_command_internal(
            image_name=f"registry.redhat.io/{OS}/mysql-{short_version}",
            service_name=self.oc_api.pod_name_prefix,
            cmd="echo 'SELECT 42 as testval\\g' | mysql --connect-timeout=15 -h <IP> testdb -utestu -ptestp",
            expected_output="42"
        )
