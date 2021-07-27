#!/usr/bin/env bash

#  Sample Env vars to deploy embedded tomcat -

export LABKEY_APP_HOME="/labkey"
export LABKEY_FILES_ROOT="/labkey/labkey/files"
export LABKEY_COMPANY_NAME="LabKey"
export LABKEY_SYSTEM_DESCRIPTION="labkey demo deployment"
export LABKEY_BASE_SERVER_URL="https://localhost"

#export LABKEY_INSTALL_SKIP_REQUIRED_ENVS_STEP=1
#export LABKEY_INSTALL_SKIP_START_LABKEY_STEP=1
export POSTGRES_SVR_LOCAL="TRUE"

export LABKEY_DIST_URL="https://lk-binaries.s3.us-west-2.amazonaws.com/downloads/release/community/21.7.0/LabKey21.7.0-2-community-embedded.tar.gz"
export LABKEY_DIST_FILENAME="LabKey21.7.0-2-community-embedded.tar.gz"
export LABKEY_VERSION="21.7.0"
export LABKEY_DISTRIBUTION="community"
