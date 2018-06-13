#!/usr/bin/env bash

# Copyright 2018 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

# creates a client CA, args are sudo, dest-dir, ca-id, purpose
# purpose is dropped in after "key encipherment", you usually want
# '"client auth"'
# '"server auth"'
# '"client auth","server auth"'
function kube::util::create_signing_certkey {
    local sudo=$1
    local dest_dir=$2
    local id=$3
    local purpose=$4
    # Create client ca
    ${sudo} /bin/bash -e <<EOF
    rm -f "${dest_dir}/${id}-ca.crt" "${dest_dir}/${id}-ca.key"
    openssl req -x509 -sha256 -new -nodes -days 365 -newkey rsa:2048 -keyout "${dest_dir}/${id}-ca.key" -out "${dest_dir}/${id}-ca.crt" -subj "/C=xx/ST=x/L=x/O=x/OU=x/CN=ca/emailAddress=x/"
    echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment",${purpose}]}}}' > "${dest_dir}/${id}-ca-config.json"
EOF
}

# signs a serving certificate: args are sudo, dest-dir, ca, filename (roughly), subject, hosts...
function kube::util::create_serving_certkey {
    local sudo=$1
    local dest_dir=$2
    local ca=$3
    local id=$4
    local cn=${5:-$4}
    local hosts=""
    local SEP=""
    shift 5
    while [ -n "${1:-}" ]; do
        hosts+="${SEP}\"$1\""
        SEP=","
        shift 1
    done
    #${sudo} /bin/bash -e <<EOF
    pushd ${dest_dir}
    echo "{\"CN\":\"${cn}\",\"hosts\":[${hosts}],\"key\":{\"algo\":\"rsa\",\"size\":2048}}" | cfssl gencert -ca=${ca}.crt -ca-key=${ca}.key -config=${ca}-config.json - | cfssljson -bare serving-${id}
    mv "serving-${id}-key.pem" "serving-${id}.key"
    mv "serving-${id}.pem" "serving-${id}.crt"
    rm -f "serving-${id}.csr"
    popd
#EOF
}

which jq &>/dev/null || { echo "Please install jq (https://stedolan.github.io/jq/)."; exit 1; }
which cfssljson &>/dev/null || { echo "Please install cfssljson (https://github.com/cloudflare/cfssl))."; exit 1; }

kubectl config current-context || { echo "Set a context (kubectl use-context <context>) out of the following:"; echo; kubectl config get-contexts; exit 1; }

# create necessary TLS certificates:
# - a local CA key and cert
# - a webhook server key and cert signed by the local CA
CERT_DIR=_output/tmp/certs
mkdir -p "${CERT_DIR}"
kube::util::create_signing_certkey "" "${CERT_DIR}" serving '"server auth"'

# create webhook server key and cert
kube::util::create_serving_certkey "" "${CERT_DIR}" "serving-ca" admission-server.federation.svc "admission-server.federation.svc" "admission-server.federation.svc"

# install RBAC rules
kubectl auth reconcile -f configs/kube-install/rbac-list.yaml
# TODO(font): remove this by either 1) removing dependency on
# NamespaceLifecycle, MutatingAdmissionWebhook, and ValidatingAdmissionWebhook
# plugins from API server. 2) add specific RBAC permissions for this API
# server to read Namespaces, MutatingWebhookConfiguration, and
# ValidatingWebhookConfiguration.
kubectl create clusterrolebinding federation-admission-server --clusterrole=cluster-admin --serviceaccount="federation:admission-server" &> /dev/null || true

# deploy the webhook as a deployment
kubectl create ns federation &>/dev/null || true
kubectl delete deployment -n federation server &>/dev/null || true
KUBE_CA=$(kubectl config view --minify=true --flatten -o json | jq '.clusters[0].cluster."certificate-authority-data"' -r)
cat configs/kube-install/apiserver-list.yaml.template | \
    sed "s/TLS_SERVING_CERT/$(base64 ${CERT_DIR}/serving-admission-server.federation.svc.crt | tr -d '\n')/g" | \
    sed "s/TLS_SERVING_KEY/$(base64 ${CERT_DIR}/serving-admission-server.federation.svc.key | tr -d '\n')/g" | \
    sed "s/SERVICE_SERVING_CERT_CA/$(base64 ${CERT_DIR}/serving-ca.crt | tr -d '\n')/g" | \
    sed "s/KUBE_CA/${KUBE_CA}/g" | \
    sed "s|YOUR_CONTAINER_REGISTRY|${REPO%/federation-admission-server}|g" | \
    kubectl apply -f -
