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

function test_platform_lsb_release() {
  assertEquals \
    'Unexpected platform name.' \
    'plan9' \
    "$(platform)"
}

function test_platform_version_lsb_release() {
  assertEquals \
    'Unexpected platform version.' \
    '4' \
    "$(platform_version)"
}

function oneTimeSetUp() {
  export LABKEY_INSTALL_SKIP_MAIN=1

  # mock lsb_release
  function lsb_release() {
    case "_${@}" in
    _*i*) echo 'Plan9' ;;
    _*r*) echo '4' ;;
    esac
  }

  # shellcheck disable=SC1091
  source install-labkey.bash
}

# shellcheck disable=SC1091
. test/shunit2
