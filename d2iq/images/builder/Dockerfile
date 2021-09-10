FROM python:3.8.2-slim-buster

ARG KUBECTL_VERSION=1.22.0
ARG KUTTL_VERSION=0.11.1
ARG HELM_VERSION=3.7.0
ARG YQ_VERSION=4.13.2
ARG KUBECTL_DOWNLOAD_URL=https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl
ARG KUTTL_DOWNLOAD_URL=https://github.com/kudobuilder/kuttl/releases/download/v${KUTTL_VERSION}/kubectl-kuttl_${KUTTL_VERSION}_linux_x86_64
ARG HELM_DOWNLOAD_URL=https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
ARG JAVA_URL=https://downloads.mesosphere.com/java/openjdk-8u212b03-hotspot-linux-x64.tar.gz
ARG YQ_URL=https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64

ENV JAVA_HOME=/usr/local/java
ENV PATH=$PATH:${JAVA_HOME}/bin

RUN apt-get update && apt-get install -y curl jq gettext-base && \
    pip install awscli && \
    curl -L ${KUBECTL_DOWNLOAD_URL} -o /usr/local/bin/kubectl && \
    curl -L ${KUTTL_DOWNLOAD_URL} -o /usr/local/bin/kubectl-kuttl && \
    for tool in kubectl*; do chmod +x /usr/local/bin/${tool}; done && \
    mkdir -p /usr/local/java && \
    curl -L -O ${JAVA_URL} && tar -xf openjdk-8u212b03-hotspot-linux-x64.tar.gz -C /usr/local/java --strip-components=1 && \
    curl -L -O ${HELM_DOWNLOAD_URL} && tar -xf helm-v${HELM_VERSION}-linux-amd64.tar.gz && cp linux-amd64/helm /usr/local/bin/ && chmod +x /usr/local/bin/helm && \
    curl -L ${YQ_URL} -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq