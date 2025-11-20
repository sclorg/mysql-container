import os

import pytest
from pathlib import Path

from container_ci_suite.helm import HelmChartsAPI

test_dir = Path(os.path.abspath(os.path.dirname(__file__)))


class TestHelmRHELMySQLImageStreams:

    def setup_method(self):
        package_name = "redhat-mysql-imagestreams"
        path = test_dir
        self.hc_api = HelmChartsAPI(path=path, package_name=package_name, tarball_dir=test_dir, shared_cluster=True)
        self.hc_api.clone_helm_chart_repo(
            repo_url="https://github.com/sclorg/helm-charts", repo_name="helm-charts",
            subdir="charts/redhat"
        )

    def teardown_method(self):
        self.hc_api.delete_project()

    @pytest.mark.parametrize(
        "version,registry",
        [
            ("8.4-el10", "registry.redhat.io/rhel10/mysql-84:latest"),
            ("8.4-el9", "registry.redhat.io/rhel9/mysql-84:latest"),
            ("8.0-el9", "registry.redhat.io/rhel9/mysql-80:latest"),
            ("8.0-el8", "registry.redhat.io/rhel8/mysql-80:latest"),
        ],
    )
    def test_package_imagestream(self, version, registry):
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation()
        assert self.hc_api.check_imagestreams(version=version, registry=registry)
