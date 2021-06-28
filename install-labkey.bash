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

if [ -n "${DEBUG:-}" ]; then
  set -x
fi

# bash strict mode
set -euo pipefail

#
# "Global" variables
#
PRODUCT='LabKey Server'

#
# Internal Utility Functions
#
function _skip_step() {
  local step_name="$1"

  if ! eval "[ -z \"\${LABKEY_INSTALL_SKIP_${step_name^^}_STEP:-}\" ]"; then
    echo "skipping '${step_name}' step"
  else
    return 1
  fi
}

function _os_release() {
  local release_dir='/etc'

  if [ -n "${SHUNIT_VERSION:-}" ]; then
    release_dir="${SHUNIT_TMPDIR:-}"
  fi

  grep -s "^${1}=" "${release_dir}/os-release" | cut -d'=' -f2- |
    tr -d '\n' | xargs | tr '[:upper:]' '[:lower:]'
}

function _lsb_release() {
  local flag="$1"

  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -s "-${flag}" | tr '[:upper:]' '[:lower:]'
  fi
}

function platform() {
  if ! _os_release 'ID'; then
    _lsb_release 'i'
  fi | xargs
}

function platform_version() {
  if ! _os_release 'VERSION_ID'; then
    _lsb_release 'r'
  fi | xargs
}

function test_console_msg() {
    assertContains \
    "Testing console_message function for Hello World!" \
    "$(console_msg 'Hello World!')"\
    "Hello World!"
}

#
# Install Steps
#
function step_intro() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  printf '%s\n\n%s' \
    "
    ${PRODUCT} CLI Install Script
  " \
    '
     __
     ||  |  _ |_ |/ _
    (__) |_(_||_)|\(/_\/
                      /
  '
}

function step_required_envs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  local ret=0

  for key in \
    LABKEY_FILES_ROOT \
    LABKEY_COMPANY_NAME \
    LABKEY_SYSTEM_DESCRIPTION \
    LABKEY_BASE_SERVER_URL; do
    local value
    value="$(env | grep -s "$key" || true)"

    if [ -z "${value%%=*}" ]; then
      echo "value required for \$${key}"
      export ret=1
    fi
  done

  return "$ret"
}

function step_download() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # attempt to download all binaries
  #   fail if URLs incorrect/download fails
  #   fail if download succeeds but it 0 bytes
  # (option) verify checksums
}

function step_outro() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  echo "
    Thank you for installing LabKey!

    Access installed LabKey from ${LABKEY_BASE_SERVER_URL:-}:${LABKEY_PORT:-}
  "
}

#
# Main loop
#
function main() {

  step_intro

  step_required_envs
  step_download

  step_outro
}

# Main function called here
if [ -z "${SHUNIT_VERSION:-}" ]; then
  main
fi
