from container_ci_suite.helm import HelmChartsAPI

from conftest import VARS


class TestHelmMySQLDBPersistent:
    def setup_method(self):
        package_name = "redhat-mysql-persistent"
        self.hc_api = HelmChartsAPI(
            path=VARS.TEST_DIR,
            package_name=package_name,
            tarball_dir=VARS.TEST_DIR,
            shared_cluster=True,
        )
        self.hc_api.clone_helm_chart_repo(
            repo_url="https://github.com/sclorg/helm-charts",
            repo_name="helm-charts",
            subdir="charts/redhat",
        )

    def teardown_method(self):
        self.hc_api.delete_project()

    def test_package_persistent(self):
        self.hc_api.package_name = "redhat-mysql-imagestreams"
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation()
        self.hc_api.package_name = "redhat-mysql-persistent"
        assert self.hc_api.helm_package()
        assert self.hc_api.helm_installation(
            values={
                "mysql_version": f"{VARS.VERSION}{VARS.TAG}",
                "namespace": self.hc_api.namespace,
                "database_service_name": "mysql",
            }
        )
        assert self.hc_api.is_pod_running(pod_name_prefix="mysql")
        assert self.hc_api.test_helm_chart(expected_str=["42", "testval"])
