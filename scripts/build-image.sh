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

PROJECT_ROOT=$(dirname "${BASH_SOURCE}")/..

# Register function to be called on EXIT to remove generated binary.
function cleanup {
  rm "${PROJECT_ROOT}/configs/image/federation-admission-server"
}
trap cleanup EXIT

pushd "${PROJECT_ROOT}"
cp -v _output/bin/federation-admission-server ./configs/image/federation-admission-server
docker build --no-cache -t ${REPO:-federation-admission-server}:latest ./configs/image
popd
