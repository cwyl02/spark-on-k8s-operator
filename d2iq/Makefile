.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS = -ec

ROOT_DIR := $(CURDIR)
SPARK_OPERATOR_DIR := $(ROOT_DIR)

export CHARTMUSEUM_PORT ?= 8080
export CHARTMUSEUM_VERSION ?= v0.13.1

export NAMESPACE ?= spark

KUBECONFIG ?= $(ROOT_DIR)/admin.conf

DOCKER_REGISTRY ?= docker.io

DOCKER_ORG ?= mesosphere

export SPARK_DOCKER_REPO ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/spark-dev
SPARK_IMAGE_DIR ?= $(ROOT_DIR)/d2iq/images/spark
export SPARK_IMAGE_TAG ?= $(call files_checksum,$(SPARK_IMAGE_DIR))
export SPARK_IMAGE_FULL_NAME ?= $(SPARK_DOCKER_REPO):$(SPARK_IMAGE_TAG)

SPARK_RELEASE_DOCKER_REPO ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/spark

export OPERATOR_DOCKER_REPO ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/kudo-spark-operator-dev
OPERATOR_IMAGE_DIR ?= $(ROOT_DIR)/d2iq/images/operator
# Excercise caution in included lists for files_checksum here. Do not include $(ROOT_DIR) as it gets new build artifacts
# Otherwise the checksum used as the image tag will always change.
export OPERATOR_VERSION ?= $(call files_checksum,$(SPARK_IMAGE_DIR) $(OPERATOR_IMAGE_DIR) $(ROOT_DIR)/pkg $(ROOT_DIR)/main.go)
export OPERATOR_IMAGE_FULL_NAME ?= $(OPERATOR_DOCKER_REPO):$(OPERATOR_VERSION)

OPERATOR_RELEASE_DOCKER_REPO ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/kudo-spark-operator

export DOCKER_BUILDER_REPO ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/spark-operator-docker-builder
DOCKER_BUILDER_IMAGE_DIR ?= $(ROOT_DIR)/d2iq/images/builder
export DOCKER_BUILDER_IMAGE_TAG ?= $(call files_checksum,$(DOCKER_BUILDER_IMAGE_DIR))
export DOCKER_BUILDER_IMAGE_FULL_NAME ?= $(DOCKER_BUILDER_REPO):$(DOCKER_BUILDER_IMAGE_TAG)

# Cluster provisioining and teardown
export AWS_PROFILE ?=
export AWS_ACCESS_KEY_ID ?= $(call get_aws_credential,aws_access_key_id)
export AWS_SECRET_ACCESS_KEY ?= $(call get_aws_credential,aws_secret_access_key)
export AWS_SESSION_TOKEN ?=$(call get_aws_credential,aws_session_token)

KUTTL_FLAGS ?=

AWS_BUCKET_NAME ?= "spark-operator-tests"
AWS_BUCKET_PATH ?= "spark-operator/tests"

# Docker
docker-builder:
	if [[ -z "$(call local_image_exists,$(DOCKER_BUILDER_IMAGE_FULL_NAME))" ]]; then
		docker build \
			-t $(DOCKER_BUILDER_IMAGE_FULL_NAME) \
			-f ${DOCKER_BUILDER_IMAGE_DIR}/Dockerfile \
			${DOCKER_BUILDER_IMAGE_DIR}
	fi
	echo $(DOCKER_BUILDER_IMAGE_FULL_NAME) > $@

docker-spark:
	if [[ -z "$(call remote_image_exists,$(SPARK_DOCKER_REPO),$(SPARK_IMAGE_TAG))" ]]; then
		docker build \
			-t ${SPARK_IMAGE_FULL_NAME} \
			-f ${SPARK_IMAGE_DIR}/Dockerfile \
			${SPARK_IMAGE_DIR}
	fi
	echo "${SPARK_IMAGE_FULL_NAME}" > $@

docker-operator: docker-spark
docker-operator:
	if [[ -z "$(call local_image_exists,$(SPARK_IMAGE_FULL_NAME))" ]]; then
		docker build \
			--build-arg SPARK_IMAGE=$(shell cat $(ROOT_DIR)/docker-spark) \
			-t ${OPERATOR_IMAGE_FULL_NAME} \
			-f ${OPERATOR_IMAGE_DIR}/Dockerfile \
			${SPARK_OPERATOR_DIR} && docker image prune -f --filter label=stage=spark-operator-builder
	fi
	echo "${OPERATOR_IMAGE_FULL_NAME}" > $@

docker-push: docker-spark
docker-push: docker-operator
docker-push: docker-builder
docker-push:
	# docker-spark
	if [[ -z "$(call remote_image_exists,$(SPARK_DOCKER_REPO),$(SPARK_IMAGE_TAG))" ]]; then
		docker push $(SPARK_IMAGE_FULL_NAME)
	fi
	# docker-operator
	if [[ -z "$(call remote_image_exists,$(OPERATOR_DOCKER_REPO),$(OPERATOR_VERSION))" ]]; then
		docker push $(OPERATOR_IMAGE_FULL_NAME)
	fi
	# docker-builder
	if [[ -z "$(call remote_image_exists,$(DOCKER_BUILDER_REPO),$(DOCKER_BUILDER_IMAGE_TAG))" ]]; then
		docker push $(DOCKER_BUILDER_IMAGE_FULL_NAME)
	fi

# Testing

.PHONY: update-spark-templates
update-spark-templates:
	# Get Spark, Scala & Hadoop version details.
	docker run -i --rm \
		-v $(ROOT_DIR):/kudo-spark-operator \
		-w /kudo-spark-operator \
		$(shell cat $(ROOT_DIR)/docker-spark) \
		/bin/bash << 'EOF'
		echo "export SPARK_VERSION=$${SPARK_VERSION}" > docker-spark-env
		echo "export SCALA_VERSION=$${SCALA_VERSION}" >> docker-spark-env
		echo "export HADOOP_VERSION=$${HADOOP_VERSION}" >> docker-spark-env
		EOF

	# Render all the templates with the correct versions.
	docker run -i --rm \
		-v $(ROOT_DIR):/kudo-spark-operator \
		-w /kudo-spark-operator \
		-e SPARK_IMAGE_FULL_NAME=$(SPARK_IMAGE_FULL_NAME) \
		-e OPERATOR_IMAGE_FULL_NAME=$(OPERATOR_IMAGE_FULL_NAME) \
		-e OPERATOR_DOCKER_REPO=$(OPERATOR_DOCKER_REPO) \
		-e OPERATOR_VERSION=$(OPERATOR_VERSION) \
		-e SPARK_DOCKER_REPO=$(SPARK_DOCKER_REPO) \
		-e SPARK_IMAGE_TAG=$(SPARK_IMAGE_TAG) \
		-e CHARTMUSEUM_PORT=$(CHARTMUSEUM_PORT) \
		$(shell cat $(ROOT_DIR)/docker-builder) \
		/bin/bash << 'EOF'
		if ! command -v yq &> /dev/null; then
		echo 'Error: yq is not installed.' >&2
		exit 1
		fi
		if ! command -v envsubst &> /dev/null; then
		echo 'Error: envsubst is not installed.' >&2
		exit 1
		fi


		# Remove stale tests
		rm -rf artifacts/tests
		# Create test folders.
		mkdir -p artifacts/tests
		# Copy templates
		cp -r d2iq/kuttl-test-templates/*  artifacts/tests

		# Get Spark, Scala & Hadoop versions.
		source docker-spark-env
		# Get all the files to process.
		test_files=$$(find artifacts/tests/ -name *.yaml*)
		for yaml in $${test_files[@]}; do
			# Replace tokens.
			sed -i "s|CHARTMUSEUM_PORT|$${CHARTMUSEUM_PORT}|g" $$yaml
			sed -i "s|SCALA_VERSION|$${SCALA_VERSION}|g" $$yaml
			sed -i "s|SPARK_VERSION|$${SPARK_VERSION}|g" $$yaml
			sed -i "s|HADOOP_VERSION|$${HADOOP_VERSION}|g" $$yaml
			sed -i "s|SPARK_IMAGE_FULL_NAME|$${SPARK_IMAGE_FULL_NAME}|g" $$yaml
			sed -i "s|OPERATOR_IMAGE_FULL_NAME|$${OPERATOR_IMAGE_FULL_NAME}|g" $$yaml
			sed -i "s|OPERATOR_DOCKER_REPO|$${OPERATOR_DOCKER_REPO}|g" $$yaml
			sed -i "s|OPERATOR_VERSION|$${OPERATOR_VERSION}|g" $$yaml
			sed -i "s|SPARK_DOCKER_REPO|$${SPARK_DOCKER_REPO}|g" $$yaml
			sed -i "s|SPARK_IMAGE_TAG|$${SPARK_IMAGE_TAG}|g" $$yaml
		done
		EOF

# This requires 'chartmuseum' container to be running.
.PHONY: kuttl-test
kuttl-test: docker-builder
kuttl-test:
	docker run -i --rm \
		--link chartmuseum \
		-v $(ROOT_DIR):/kudo-spark-operator \
		-v $(KUBECONFIG):/root/.kube/config \
		-w /kudo-spark-operator \
		-e ROOT_DIR=/kudo-spark-operator \
		-e KUBECONFIG=/root/.kube/config \
		-e OPERATOR_DOCKER_REPO=$(OPERATOR_DOCKER_REPO) \
		-e OPERATOR_VERSION=$(OPERATOR_VERSION) \
		-e AWS_ACCESS_KEY_ID="$(AWS_ACCESS_KEY_ID)" \
		-e AWS_SECRET_ACCESS_KEY="$(AWS_SECRET_ACCESS_KEY)" \
		-e AWS_SESSION_TOKEN="$(AWS_SESSION_TOKEN)" \
		-e AWS_BUCKET_NAME=$(AWS_BUCKET_NAME) \
		-e AWS_BUCKET_PATH=$(AWS_BUCKET_PATH) \
		$(shell cat $(ROOT_DIR)/docker-builder) \
		kubectl kuttl test --parallel 1 --namespace $(NAMESPACE) --report xml artifacts/tests $(KUTTL_FLAGS)

# Run chartmuseum to host dev versions of the helm package.
# The container will be called 'chartmuseum' and we link to
# it when running tests etc...
.PHONY: chartmuseum
chartmuseum:
	mkdir -p  $(ROOT_DIR)/artifacts/chartstorage
	# Run chartmuseum docker image called "chartmuseum"
	docker run --rm -it \
  		--name chartmuseum \
  		-p $(CHARTMUSEUM_PORT):$(CHARTMUSEUM_PORT) \
  		-e DEBUG=1 \
  		-e STORAGE=local \
  		-e STORAGE_LOCAL_ROOTDIR=/chartstorage \
  		-v $(ROOT_DIR)/artifacts/chartstorage:/chartstorage \
  		ghcr.io/helm/chartmuseum:$(CHARTMUSEUM_VERSION)

.PHONY: helm-package-chart
helm-package-chart: docker-builder
helm-package-chart:
	mkdir -p  $(ROOT_DIR)/artifacts/charts
	docker run -i --rm \
			-v $(ROOT_DIR):/kudo-spark-operator \
			-w /kudo-spark-operator \
			$(shell cat $(ROOT_DIR)/docker-builder) \
			helm package -d artifacts/charts charts/spark-operator-chart 

# Push packaged helm chart to chartmuseum
# This requires 'chartmuseum' container to be running.
.PHONY: push-package-chartmuseum
push-package-chartmuseum: helm-package-chart
	docker run -i --rm \
			--link chartmuseum \
			-v $(ROOT_DIR):/kudo-spark-operator \
			-w /kudo-spark-operator \
			$(shell cat $(ROOT_DIR)/docker-builder) \
			/bin/bash << 'EOF'
			for chart in artifacts/charts/*.tgz;
				# NOTE: Do NOT quote the @$${chart} here, otherwise we just upload the name of the file causing errors.
				do curl --data-binary @$${chart} http://chartmuseum:8080/api/charts;
			done
			EOF

.PHONY: release-spark
release-spark: docker-spark
release-spark:
	$(call tag_and_push_image,$(SPARK_RELEASE_DOCKER_REPO),$(SPARK_IMAGE_RELEASE_TAG),$(SPARK_IMAGE_FULL_NAME))

.PHONY: release-operator
release-operator: docker-operator
release-operator:
	$(call tag_and_push_image,$(OPERATOR_RELEASE_DOCKER_REPO),$(OPERATOR_IMAGE_RELEASE_TAG),$(OPERATOR_IMAGE_FULL_NAME))

.PHONY: clean-docker
clean-docker:
	rm -f docker-*

.PHONY: clean-all
clean-all: clean-docker
clean-all:
	rm -f *.pem *.pub *-created aws_credentials
	rm -rf state runs .konvoy-* *checksum cluster.yaml* inventory.yaml admin.conf

# function for extracting the value of an AWS property passed as an argument
define get_aws_credential
$(if $(AWS_PROFILE),$(shell cat ~/.aws/credentials | grep ${AWS_PROFILE} -A4 | tail -n4 | grep $1 | xargs | cut -d ' ' -f3),$(warning unable to update $1 from AWS credentials file: AWS_PROFILE is not provided. $1 will not be set))
endef

# function for calculating global checksum of directories and files passed as arguments.
# to avoid inconsistencies with files ordering in Linux/Unix systems the final checksum is
# calculated based on sorted checksums of independent files stored in a temporary file
#
# arguments:
# $1 - space-separated list of directories and/or files
define files_checksum
$(shell find $1 -type f | xargs sha1sum | cut -d ' ' -f1 > tmp.checksum && sort tmp.checksum | sha1sum | cut -d' ' -f1)
endef

# arguments:
# $1 - image name with repo e.g. mesosphere/spark
# $2 - image tag e.g. latest
define remote_image_exists
$(shell curl --silent --fail --list-only --location https://index.docker.io/v1/repositories/$1/tags/$2 2>/dev/null)
endef

define local_image_exists
$(shell docker images -q $1 2> /dev/null)
endef

# arguments:
# $1 - release image repo, e.g. mesosphere/spark
# $2 - release image tag, e.g spark-3.0.0-hadoop-2.9-k8s
# $3 - dev image full name, e.g mesosphere/spark-dev:ab36f1f3691a8be2050f3acb559c34e3e8e5d66e
define tag_and_push_image
	$(eval RELEASE_IMAGE_FULL_NAME=$(1):$(2))
	# check, if specified image already exists to prevent overwrites
	if [[ -z "$(call remote_image_exists,$(1),$(2))" ]]; then
		docker pull $(3)
		docker tag $(3) $(RELEASE_IMAGE_FULL_NAME)
		echo "Pushing image \"$(RELEASE_IMAGE_FULL_NAME)\""
		docker push $(RELEASE_IMAGE_FULL_NAME)
	else
		echo "Error: image \"$(RELEASE_IMAGE_FULL_NAME)\" already exists, will not proceed with overwrite."; false
	fi
endef
