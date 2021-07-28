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

function test_intro() {
  assertContains \
    "Intro didn't mention its own name." \
    "$(step_intro)" \
    "CLI Install Script"
}

function oneTimeSetUp() {
  export LABKEY_INSTALL_SKIP_MAIN=1

  # shellcheck disable=SC1091
  source install-labkey.bash
}

# shellcheck disable=SC1091
. test/shunit2
