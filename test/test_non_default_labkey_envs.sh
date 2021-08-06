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

# verify the set LABKEY_VERSION made it into the dist url
function test_non_default_labkey_version_url() {
  # shellcheck disable=SC2016
  assertContains \
    'non-default $LABKEY_VERSION not in $LABKEY_DIST_URL' \
    "$LABKEY_DIST_URL" \
    'infinite'
}

# verify the set LABKEY_COMPANY_NAME made it into the startup props
function test_non_default_company_prop() {
  # shellcheck disable=SC2016
  assertNotEquals \
    'non-default $LABKEY_COMPANY_NAME not in startup properties' \
    '' \
    "$(
      grep -s -r 'Megadodo Publications' "$LABKEY_STARTUP_DIR" || true
    )"
}

function oneTimeSetUp() {
  export SKIP_MAIN=1

  # shellcheck disable=SC1091,SC1090
  source "install-${TEST_PRODUCT:-labkey}.bash"

  # shellcheck source=test/helpers.sh
  source test/helpers.sh

  export LABKEY_VERSION='infinite'
  export LABKEY_COMPANY_NAME='Megadodo Publications'

  step_default_envs
  step_create_required_paths >/dev/null 2>&1
  step_startup_properties
}

# shellcheck disable=SC1091
. test/shunit2
