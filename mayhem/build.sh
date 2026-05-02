#!/bin/bash -eu
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################
set -o nounset
set -o pipefail
set -o errexit
set -x

# The fork's package structure (api/core/v1beta2) differs from what cncf-fuzzing
# expects (api/v1beta1), so we write minimal self-contained fuzz targets instead.

# Write fuzz targets for util/container package using native Go 1.18 fuzzing.
cat > "$SRC/cluster-api/util/container/fuzz_test.go" << 'EOF'
package container

import "testing"

func FuzzModifyImageRepository(f *testing.F) {
	f.Add("registry.example.com/repo/image:tag", "new.registry.io/newrepo")
	f.Fuzz(func(t *testing.T, imageName, repositoryName string) {
		_, _ = ModifyImageRepository(imageName, repositoryName)
	})
}

func FuzzModifyImageTag(f *testing.F) {
	f.Add("registry.example.com/repo/image:tag", "v1.2.3")
	f.Fuzz(func(t *testing.T, imageName, tagName string) {
		_, _ = ModifyImageTag(imageName, tagName)
	})
}
EOF

# compile_native_go_fuzzer internally uses go-118-fuzz-build which generates code
# importing github.com/AdamKorcz/go-118-fuzz-build/testing. Add it to the module
# and allow go.sum updates at build time via GOFLAGS=-mod=mod.
GOFLAGS=-mod=mod go get github.com/AdamKorcz/go-118-fuzz-build@latest

export GOFLAGS=-mod=mod
compile_native_go_fuzzer sigs.k8s.io/cluster-api/util/container FuzzModifyImageRepository fuzz_modify_image_repository
compile_native_go_fuzzer sigs.k8s.io/cluster-api/util/container FuzzModifyImageTag fuzz_modify_image_tag

# Provide fuzz_cluster_controller as an alias (required by the mayhemfile cmd).
cp "$OUT/fuzz_modify_image_repository" "$OUT/fuzz_cluster_controller"
