#!/usr/bin/env bash

#  Sample Env vars to deploy embedded tomcat -

export LABKEY_APP_HOME="/labkey"
export LABKEY_FILES_ROOT="/labkey/labkey/files"
export LABKEY_COMPANY_NAME="LabKey"
export LABKEY_SYSTEM_DESCRIPTION="labkey demo deployment"
export LABKEY_BASE_SERVER_URL="https://localhost"

export POSTGRES_SVR_LOCAL="TRUE"
export POSTGRES_VERSION="16"

export LABKEY_DIST_URL="https://s3.us-west-2.amazonaws.com/build.labkey.com/LabKey24.3Beta-15-community-embedded.tar.gz"
export LABKEY_DIST_FILENAME="LabKey24.3Beta-15-community-embedded.tar.gz"
export LABKEY_VERSION="24.3-SNAPSHOT"
export LABKEY_DISTRIBUTION="community"

# Some Rhel based distro's don't like 4 digit UID's
export TOMCAT_UID="757"

# required for tomcat 10 embedded as the server/ folder will be removed in 24.3.x
export LABKEY_STARTUP_DIR="${LABKEY_INSTALL_HOME}/startup}"
