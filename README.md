# federation-admission-server

Federation Admission Server that handles validation of Federation-v2 resources.

## Prerequisites

0. Make sure to have at least Kubernetes 1.9.
1. `kubectl` working.
1. `jq`, `cfssl` and `cfssljson` installed.
1. Clone this repo.

## Installation

0. Run `make build-image push-image REPO=<your-registry>/<username>/federation-admission-server`
1. Run `make install REPO=<your-registry>/<username>/federation-admission-server`

## Test Setup

0. Clone repo into your go workspace: `git clone https://github.com/font/fedv2-crd-validation.git`
1. `cd fedv2-crd-validation`
1. Build the controller: `GOBIN=${PWD}/bin go install ${PWD#$GOPATH/src/}/cmd/controller-manager`
1. Run the controller: `bin/controller-manager --kubeconfig ~/.kube/config`
1. Run `kubectl create ns test-namespace`
1. Run `kubectl create -f example/sample1/federateddeployment-template.yaml`
   should produce:
   `Error from server (Forbidden): admission webhook
   "validations.admission.federation.k8s.io" denied the request: dummy failure`
