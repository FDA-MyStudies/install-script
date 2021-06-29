#!/usr/bin/env bash

#
# Copyright (c) 2021 LabKey Corporation
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
#

function test_create_labkey_home() {
  assertTrue \
  "directory missing $LABKEY_APP_HOME" \
  "[ -d '${LABKEY_APP_HOME}' ]"
}

function test_create_tomcat_install_home() {
  assertTrue 'directory missing '$TOMCAT_INSTALL_HOME "[ -d '${TOMCAT_INSTALL_HOME}' ]"
}

oneTimeSetUp() {
  # shellcheck disable=SC1091
  source sample_set_envs.sh
  source install-labkey.bash
  step_create_required_paths
  #Disbale pipefail as ShUnit2 has a bug with AssertTrue & AssertFalse https://github.com/kward/shunit2/issues/141
  set +euo pipefail
}

oneTimeTearDown() {
  rm -Rf "${LABKEY_APP_HOME}"
}

# shellcheck disable=SC1091
. test/shunit2
