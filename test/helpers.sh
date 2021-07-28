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

function uuidgen() {
  echo 'BEEFBEEF-BEEF-1234-BEEF-BEEFBEEFBEEF'
}

function openssl() {
  printf '%s\n%s' \
    'FzPEJL8z5dV4LnJj1Nu+2mFGtZCkvDkWpLIJpWs4lwfiq/tpUJGpNk9OkNkm1gfX' \
    'x1h+E48FidB8h7ijT/MJUw=='
}

function lsb_release() {
  local mock_platform="${MOCK_PLATFORM:-plan9}"

  case "_${mock_platform}" in
  _plan9)
    case "_${@}" in
    _*i*) echo 'Plan9' ;;
    _*r*) echo '4' ;;
    esac
    ;;
  _amzn)
    case "_${@}" in
    _*i*) echo 'Amazon' ;;
    _*r*) echo '2' ;;
    esac
    ;;
  esac
}
