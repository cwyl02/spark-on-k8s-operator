#!/bin/bash

set -ex
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
SCALE_TESTS_DIR="$(dirname "${SCRIPT_DIR}")"
PROJECT_ROOT_DIR="$(dirname "${SCALE_TESTS_DIR}")"

TEMPLATES_DIR="${SCALE_TESTS_DIR}/templates"
# SPECS_DIR="${PROJECT_ROOT_DIR}/specs"
# OPERATOR_DIR="${PROJECT_ROOT_DIR}/kudo-spark-operator/operator"
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-spark-service-account}

NAMESPACE_PREFIX=${NAMESPACE_PREFIX:-spark-operator}
INSTANCE_NAME_PREFIX=${INSTANCE_NAME_PREFIX:-spark-operator}
OPERATOR_VERSION=${OPERATOR_VERSION:-3.1.1-1.1.6}
WORKSPACE_NS_PREFIX=${WORKSPACE_NS_PREFIX:-mwt-workspace-}
PROJECT_NS_PREFIX=${PROJECT_NS_PREFIX:-mwt-project-}

# BRANCH_NAME=${BRANCH:-d2iq-spark-operator-chart-1.1.7}

if [[ $# -lt 1 ]]; then
  echo "Usage:" >&2
  echo "  $0 <number of operator instances (and namespaces) to create>" >&2
  exit 1
fi

# TODO: put this at a separate step
# kubectl apply -f ${TEMPLATES_DIR}/dkp-catalog-repo.yaml

#  get all WS ns
k get ns -A -o json  | jq '.items | .[] | .metadata.name'  -r | grep $WORKSPACE_NS_PREFIX > workspaces.txt

cat workspaces.txt | while read line 
do
  echo "installing spark-operator resources in workspace ns: $line"
  #  NAMESPACE="${NAMESPACE_PREFIX}-${i}"
  NAMESPACE=$line
  kubectl apply -f ${TEMPLATES_DIR}/dkp-catalog-repo.yaml -n $NAMESPACE
  # echo "Creating namespace $NAMESPACE"
  # sed 's|SPARK_NAMESPACE|'"${NAMESPACE}"'|g' ${TEMPLATES_DIR}/namespace.tmpl | kubectl apply -f -
  echo "Creating service account ${SERVICE_ACCOUNT_NAME}"
  sed 's|SERVICE_ACCOUNT_NAME|'"${SERVICE_ACCOUNT_NAME}"'|g' ${TEMPLATES_DIR}/service-account.tmpl | kubectl apply --namespace "${NAMESPACE}" -f -
  kubectl apply --namespace "${NAMESPACE}" -f ${TEMPLATES_DIR}/configmap-override.tmpl
  sed 's|SPARK_NAMESPACE|'"${NAMESPACE}"'|g' ${TEMPLATES_DIR}/app-deployment.tmpl | kubectl apply -f -
done

# install CRDs
kubectl apply -f $PROJECT_ROOT_DIR/manifest/crds

# for i in $(seq ${1}); do
#     NAMESPACE="${NAMESPACE_PREFIX}-${i}"
#     echo "Creating namespace $NAMESPACE"
#     sed 's|SPARK_NAMESPACE|'"${NAMESPACE}"'|g' ${TEMPLATES_DIR}/namespace.tmpl | kubectl apply -f -
#     sed 's|SERVICE_ACCOUNT_NAME|'"${SERVICE_ACCOUNT_NAME}"'|g' ${TEMPLATES_DIR}/service-account.tmpl | kubectl apply --namespace "${NAMESPACE}" -f -
#     kubectl apply --namespace "${NAMESPACE}" -f ${TEMPLATES_DIR}/configmap-override.tmpl
#     sed 's|SPARK_NAMESPACE|'"${NAMESPACE}"'|g' ${TEMPLATES_DIR}/app-deployment.tmpl | kubectl apply -f -
    
    # kubectl kudo --namespace "${NAMESPACE}" install --instance "${INSTANCE_NAME_PREFIX}-${i}" spark \
    #         -p operatorVersion="${OPERATOR_VERSION}" \
    #         -p sparkServiceAccountName="${SERVICE_ACCOUNT_NAME}" \
    #         -p createSparkServiceAccount=false \
    #         -p enableMetrics=true \
    #         -p sparkJobNamespace="${NAMESPACE}"
# done

# for i in $(seq ${1}); do
#     kubectl wait --for=condition=Available deployment --all  --namespace "$NAMESPACE" --timeout=120s || sleep 1
# done
