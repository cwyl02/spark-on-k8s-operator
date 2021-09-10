# Spark Operator

The `d2iq` fork adds additional features to the the upstream `spark-on-k8s-operator`

Specifically the following features are present:
- Spark History Server
- Hadoop Cloud
- R Support 

The main set of changes are found in the `d2iq` folder with modifications done to `charts` and the main `Makefile`.
The emphasis is for easy maintainability of this fork and to allow easy rebases on the upstream repository.

## Branch Layout

Branch | Status | Notes
-------|--------|------
main | protected | Tracks upstream `main` from `spark-on-k8s-operator`
d2iq-main | protected | D2iQ patches rebased on upstream `main` branch. Default branch of this fork.
d2iq-pages | protected | D2iQ `spark-operator` Helm chart hosted via [Github Pages](https://helm.sh/docs/topics/chart_repository/#github-pages-example)
d2iq-spark-operator-chart-X.Y.Z | feature | Branch with upstream chart X.Y.Z with rebased patches.

## Images

- `images/spark` : Contains build tooling for the base Spark image.
- `images/operator` : Contains build tooling for the Spark Operator image, this image uses the `spark` image above.
- `images/builder` : Contains build tooling (helm, kuttl, jq, yq, etc...) needed to test spark-operator.
- `images/hadoop-kerberos` : Contains build tooling to create the hadoop-kerberos images used in the HDFS Kerberos test suite. 

## Requirements

- AWS Credentials, specifically the following from `~/.aws/credentials`
    - AWS_PROFILE
    - AWS_ACCESS_KEY_ID
    - AWS_SECRET_ACCESS_KEY
    - AWS_SESSION_TOKEN
- AWS S3 Bucket (read/write/create/list permissiones), configured by
    - AWS_BUCKET_NAME
    - AWS_BUCKET_PATH
- Kubernetes Cluster configured
    - Set `admin.conf` in top level folder with administrative Kubeconfig file.
    - Set `KUBECONFIG` env-var with path to the administrative Kubeconfig file.

## Makefile Targets

Target | Notes
-------|------
docker-spark |  Create image from `images/spark`
docker-operator | Create image from `images/operator`
docker-builder | Create image from `images/builder`
docker-push | Push all images above.
chartmuseum | Start local [Chartmuseum](https://github.com/helm/chartmuseum) to host Helm Repostiory for integration tests.
helm-package-chart | Create a Helm chart `tgz` file.
push-package-chartmuseum | Push Helm chart `tgz` file to running Chart Museum.
update-spark-templates | Update KUTTL test templates with appropriate test environment
kuttl-test | Run KUTTL integration tests.

## Integration Tests

The integration tests use [KUTTL](https://kuttl.dev/docs/what-is-kuttl.html) for testing.

All test artifacts are created in the top-level `artifacts` folder.
KUTTL Results are found in the `kuttl-test.xml` file.

`d2iq/kuttl-test-templates` contain all the integration tests, the Makefile target `update-spark-templates` copies these tests to `artifacts/tests` and issues a token replace on variables such as `SPARK_IMAGE_FULL_NAME`, `SCALA_VERSION`, `HADOOP_VERSION` to use the current versions under test.

The process for running a full test suite:

Step | Target | Notes
-----|--------|------
1.|Set `admin.conf` or `KUBECONFIG` env-var with kubeconfig file to the cluster. | Set target cluster.
2.|`make aws-credentials` | Set AWS Credentials
3.|`make docker-spark` | Create base spark image, if not already done.
4.|`make docker-operator` | Create spark-operator image, if not already done.
5.|`make docker-builder` | Create tooling image, if not already done.
6.|`make docker-push` | Push spark and spark-operator images for k8s cluster to use during testing.
7.|`make chartmuseum` |  Start Chartmusem container to host the Helm Repository.
8.|`make helm-package-chart` | Create `tgz` Helm Chart to `artifacts/charts`
9.|`make push-package-chartmuseum` | Push `tgz` Helm Chart to Chart museum.
10.|`make --trace update-spark-templates` | Replace token values such as `SCALA_VERSION`, `HADOOP_VERSION`, etc.. with values currently under test
11.|`make --trace kuttl-test` | Run KUTTL Test Suite from `artifacts/tests` folder.
