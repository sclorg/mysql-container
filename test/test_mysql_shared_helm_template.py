import os

import pytest
from pathlib import Path

from container_ci_suite.helm import HelmChartsAPI

test_dir = Path(os.path.abspath(os.path.dirname(__file__)))


class TestHelmMySQLDBPersistent:

    def setup_method(self):
        package_name = "redhat-mysql-persistent"
        path = test_dir
        self.hc_api = HelmChartsAPI(path=path, package_name=package_name, tarball_dir=test_dir, shared_cluster=True)
        self.hc_api.clone_helm_chart_repo(
            repo_url="https://github.com/sclorg/helm-charts", repo_name="helm-charts",
            subdir="charts/redhat"
        )

    def teardown_method(self):
        self.hc_api.delete_project()

    @pytest.mark.parametrize(
        "version",
        [
            "8.0-el8",
            "8.0-el9",
        ],
    )
    def test_package_persistent(self, version):
        self.hc_api.package_name = "redhat-mysql-imagestreams"
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation()
        self.hc_api.package_name = "redhat-mysql-persistent"
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation(values={"mysql_version": version, "namespace": self.hc_api.namespace})
        assert self.hc_api.is_pod_running(pod_name_prefix="mysql")
        assert self.hc_api.test_helm_chart(expected_str=["42", "testval"])
