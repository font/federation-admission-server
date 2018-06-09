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

all: build
.PHONY: all

REPO ?=

build:
	go build -o _output/bin/federation-admission-server cmd/federation-admission-server/main.go
.PHONY: build

build-image:
	GOOS=linux go build -o _output/bin/federation-admission-server cmd/federation-admission-server/main.go
	REPO=$(REPO) scripts/build-image.sh
.PHONY: build-image

push-image:
	docker push $(REPO):latest
.PHONY: push-image

install:
	REPO=$(REPO) scripts/install-kube.sh
.PHONY: install

clean:
	rm -rf _output/bin
.PHONY: clean

update-deps:
	scripts/update-deps.sh
.PHONY: generate
