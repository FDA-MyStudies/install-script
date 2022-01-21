#!/usr/bin/env bash

# The LabKey Install-Script is broken out into to step functions. Each STEP can be skipped by exporting the
# corresponding environment variable with the following syntax:
# export LABKEY_INSTALL_SKIP_<<FUNCTION_NAME>>_STEP=1
#         or (example)
# export LABKEY_INSTALL_SKIP_DOWNLOAD_STEP=1
# skips the function "step_download()"
#
# Sample Env vars to install/update only Tomcat (includes Java and OS Dependencies)
#
# ATTENTION - ATTENTION - ATTENTION - ATTENTION - ATTENTION - ATTENTION -ATTENTION - ATTENTION
# If you plan to use this to update an existing deployment, please note that customized tomcat configuration
# files will be replaced with defaults from the script.  You should backup any customized Tomcat configurations such
# server.xml, ROOT.xml/labkey.xml etc.

# Define required defaults - If you installed LabKey with this script previously, these VARS should match your previous
# installation settings.
export LABKEY_APP_HOME="/labkey"
export LABKEY_FILES_ROOT="/labkey/labkey/files"
export LABKEY_COMPANY_NAME="LabKey"
export LABKEY_SYSTEM_DESCRIPTION="labkey demo deployment"
export LABKEY_BASE_SERVER_URL="https://localhost"
export TOMCAT_INSTALL_HOME="${LABKEY_APP_HOME}/apps/tomcat"
export TOMCAT_INSTALL_TYPE="Standard"
export TOMCAT_VERSION="9.0.50"
# Optional Tomcat settings if wish to deploy using TCP 80/443
export TOMCAT_USE_PRIVILEGED_PORTS="TRUE"
export LABKEY_HTTP_PORT=80
export LABKEY_HTTPS_PORT=443
# REQUIRED - REQUIRED - REQUIRED - REQUIRED - REQUIRED - REQUIRED
# Use fixed values for Secrets to facilitate future updates or reuse of this script to update to future versions of tomcat
# If you previously deployed using the install-script these should match your existing deployment settings
export TOMCAT_USERNAME="tomcat"
export TOMCAT_KEYSTORE_PASSWORD="changeme"
export POSTGRES_PASSWORD="changeme"
export POSTGRES_USER="labkey"

# Skip installation steps except those needed to install Tomcat
# Need Intro and Default ENVS
#export LABKEY_INSTALL_SKIP_INTRO_STEP=1
#export LABKEY_INSTALL_SKIP_DEFAULT_ENVS_STEP=1

export LABKEY_INSTALL_SKIP_REQUIRED_ENVS_STEP=1
export LABKEY_INSTALL_SKIP_CREATE_REQUIRED_PATHS_STEP=1
export LABKEY_INSTALL_SKIP_DOWNLOAD_STEP=1
export LABKEY_INSTALL_SKIP_CREATE_APP_PROPERTIES_STEP=1
export LABKEY_INSTALL_SKIP_STARTUP_PROPERTIES_STEP=1
export LABKEY_INSTALL_SKIP_POSTGRES_CONFIGURE_STEP=1
# Tomcat user required for fresh install - this step can be skipped for update tomcat use cases
export LABKEY_INSTALL_SKIP_TOMCAT_USER_STEP=1
# Optional Self-Signed Tomcat_Cert will be recreated unless skipped
#export LABKEY_INSTALL_SKIP_TOMCAT_CERT_STEP=1
export LABKEY_INSTALL_SKIP_CONFIGURE_LABKEY_STEP=1
export LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_EMBEDDED_STEP=1
# Use the Tomcat Service Function to install an updated version of Tomcat
#export LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_STANDARD_STEP=1
export LABKEY_INSTALL_SKIP_ALT_FILES_LINK_STEP=1
export LABKEY_INSTALL_SKIP_START_LABKEY_STEP=1

# Not needed but useful to know install finished
export LABKEY_INSTALL_SKIP_OUTRO_STEP=1
