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

function test_non_default_app_home() {
  # skip on wcp
  if [[ ${TEST_PRODUCT:-} == 'wcp' ]]; then
    startSkipping
  fi

  # shellcheck disable=SC2016
  assertContains \
    'non-default $LABKEY_APP_HOME not created' \
    "$(step_create_required_paths)" \
    'creating /opt/yekbal'
}

function test_non_default_install_home() {
  # skip on wcp
  if [[ ${TEST_PRODUCT:-} == 'wcp' ]]; then
    startSkipping
  fi

  # shellcheck disable=SC2016
  assertContains \
    'non-default $LABKEY_INSTALL_HOME not created' \
    "$(step_create_required_paths)" \
    'creating /opt/yekbal/labkey'
}

function oneTimeSetUp() {
  export SKIP_MAIN=1

  # shellcheck disable=SC1091,SC1090
  source "install-${TEST_PRODUCT:-labkey}.bash"

  # shellcheck source=test/helpers.sh
  source test/helpers.sh

}

function setUp() {
  export LABKEY_APP_HOME='/opt/yekbal'

  step_default_envs
}

function tearDown() {
  rm -rf '/opt/yekbal'
}

# shellcheck disable=SC1091
. test/shunit2
