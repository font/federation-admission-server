/*
Copyright 2018 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"flag"
	"net/http"
	"os"
	"runtime"

	"github.com/golang/glog"
	"github.com/openshift/generic-admission-server/pkg/apiserver"
	"github.com/openshift/generic-admission-server/pkg/cmd/server"

	admissionv1beta1 "k8s.io/api/admission/v1beta1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
	genericapiserver "k8s.io/apiserver/pkg/server"
	"k8s.io/apiserver/pkg/util/logs"
	"k8s.io/client-go/rest"
)

func main() {
	glog.Info("Running admission server...")
	// Run server
	runAdmissionServer(&admissionHook{})
}

// Originally from: https://github.com/openshift/generic-admission-server/blob/v1.9.0/pkg/cmd/cmd.go
func runAdmissionServer(admissionHooks ...apiserver.AdmissionHook) {
	logs.InitLogs()
	defer logs.FlushLogs()

	if len(os.Getenv("GOMAXPROCS")) == 0 {
		runtime.GOMAXPROCS(runtime.NumCPU())
	}

	stopCh := genericapiserver.SetupSignalHandler()

	cmd := server.NewCommandStartAdmissionServer(os.Stdout, os.Stderr, stopCh, admissionHooks...)
	cmd.Short = "Launch Fedv2 Validation Admission Server"
	cmd.Long = "Launch Fedv2 Validation Admission Server"

	// Flags for glog
	cmd.PersistentFlags().AddGoFlagSet(flag.CommandLine)
	// Fix glog printing "Error: logging before flag.Parse"
	flag.CommandLine.Parse([]string{})

	if err := cmd.Execute(); err != nil {
		glog.Fatal(err)
	}
}

type admissionHook struct {
}

func (a *admissionHook) ValidatingResource() (plural schema.GroupVersionResource, singular string) {
	glog.Info("Webhook ValidatingResource")
	return schema.GroupVersionResource{
			Group:    "admission.federation.k8s.io",
			Version:  "v1alpha1",
			Resource: "validations",
		},
		"validations"
}

func (a *admissionHook) Validate(admissionSpec *admissionv1beta1.AdmissionRequest) *admissionv1beta1.AdmissionResponse {
	glog.Info("Webhook Validate")
	status := &admissionv1beta1.AdmissionResponse{}
	status.Allowed = false
	status.Result = &metav1.Status{
		Status: metav1.StatusFailure, Code: http.StatusForbidden, Reason: metav1.StatusReasonForbidden,
		Message: "dummy failure",
	}
	return status
}

func (a *admissionHook) Initialize(kubeClientConfig *rest.Config, stopCh <-chan struct{}) error {
	glog.Info("Webhook Initialize")
	return nil
}
