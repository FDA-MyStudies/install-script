#!/usr/bin/env bash

# The LabKey Install-Script is broken out into step functions.  Each STEP can be skipped by exporting the
# corresponding environment variable with the following syntax:
# export LABKEY_INSTALL_SKIP_<<Function_NAME>>_STEP=1
#         or
# export LABKEY_INSTALL_SKIP_DOWNLOAD_STEP=1
# to skip the function "step_download()"
#
# Sample Env vars to install/update only Java

# Define required defaults - If you installed LabKey with this script previously, these VARS should match your previous
# installation settings.
export LABKEY_APP_HOME="/labkey"
export LABKEY_FILES_ROOT="/labkey/labkey/files"
export LABKEY_COMPANY_NAME="LabKey"
export LABKEY_SYSTEM_DESCRIPTION="labkey demo deployment"
export LABKEY_BASE_SERVER_URL="https://localhost"
export TOMCAT_INSTALL_HOME="${LABKEY_APP_HOME}/apps/tomcat"
export TOMCAT_INSTALL_TYPE="Standard"

# Skip installation steps except those needed to install java and other OS specific dependencies.
export LABKEY_INSTALL_SKIP_REQUIRED_ENVS_STEP=1
export LABKEY_INSTALL_SKIP_CREATE_REQUIRED_PATHS_STEP=1
export LABKEY_INSTALL_SKIP_DOWNLOAD_STEP=1
export LABKEY_INSTALL_SKIP_CREATE_APP_PROPERTIES_STEP=1
export LABKEY_INSTALL_SKIP_STARTUP_PROPERTIES_STEP=1
export LABKEY_INSTALL_SKIP_POSTGRES_CONFIGURE_STEP=1
export LABKEY_INSTALL_SKIP_TOMCAT_USER_STEP=1
export LABKEY_INSTALL_SKIP_TOMCAT_CERT_STEP=1
export LABKEY_INSTALL_SKIP_CONFIGURE_LABKEY_STEP=1
export LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_EMBEDDED_STEP=1
export LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_STANDARD_STEP=1
export LABKEY_INSTALL_SKIP_ALT_FILES_LINK_STEP=1
export LABKEY_INSTALL_SKIP_START_LABKEY_STEP=1

# Not needed but useful to know install finished
export LABKEY_INSTALL_SKIP_OUTRO_STEP=1
