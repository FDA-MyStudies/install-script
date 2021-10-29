#!/usr/bin/env bash

# Sample Env vars to deploy standard tomcat - e.g. non-embedded

export LABKEY_APP_HOME="/labkey"
export LABKEY_FILES_ROOT="/labkey/labkey/files"
export LABKEY_COMPANY_NAME="LabKey"
export LABKEY_SYSTEM_DESCRIPTION="labkey demo deployment"
export LABKEY_BASE_SERVER_URL="https://localhost"

#export LABKEY_INSTALL_SKIP_REQUIRED_ENVS_STEP=1
#export LABKEY_INSTALL_SKIP_START_LABKEY_STEP=1
export POSTGRES_SVR_LOCAL="TRUE"
export TOMCAT_INSTALL_HOME="${LABKEY_APP_HOME}/apps/tomcat"

export LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_EMBEDDED_STEP=1
export TOMCAT_INSTALL_TYPE="Standard"
export LABKEY_DIST_URL="https://lk-binaries.s3.us-west-2.amazonaws.com/downloads/release/community/21.7.0/LabKey21.7.0-2-community.tar.gz"
export LABKEY_DIST_FILENAME="LabKey21.7.0-2-community.tar.gz"
export LABKEY_VERSION="21.7.0"
export LABKEY_DISTRIBUTION="community"
export LABKEY_LOG_DIR="/labkey/apps/tomcat/logs"
export LABKEY_CONFIG_DIR="/labkey/apps/tomcat/config"
export LABKEY_STARTUP_DIR="/labkey/labkey/startup"

#export TOMCAT_USE_PRIVILEGED_PORTS="TRUE"
#export LABKEY_HTTP_PORT=80
#export LABKEY_HTTPS_PORT=443
