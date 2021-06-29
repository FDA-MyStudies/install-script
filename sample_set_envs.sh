#!/usr/bin/env bash

# Configure the env vars to use for the installer

export LABKEY_COMPANY_NAME="LabKey"
export LABKEY_SYSTEM_DESCRIPTION="labkey test deployment"
export LABKEY_BASE_SERVER_URL="http://localhost"
export LABKEY_FILES_ROOT="/labkey/files"

export LABKEY_VERSION="21.6.0"
export LABKEY_DISTRIBUTION="community"


# tomcat properties

export LABKEY_APP_HOME="/tmp/labkey"
export TOMCAT_INSTALL_HOME="$LABKEY_APP_HOME/apps/tomcat"

# tomcat properties used in application.properties
export LOG_LEVEL_TOMCAT="OFF"
export LOG_LEVEL_SPRING_WEB="OFF"
export LOG_LEVEL_SQL="OFF"
# shellcheck disable=SC2155
export TOMCAT_KEYSTORE_PASSWORD="$( openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)"
# shellcheck disable=SC2155
export LABKEY_MEK="$( openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)"
# shellcheck disable=SC2155
export LABKEY_GUID=$(uuidgen)


# postgres properties
export POSTGRES_HOST="localhost"
export POSTGRES_DB="labkey"
export POSTGRES_USER="labkey"
# shellcheck disable=SC2155
export POSTGRES_PASSWORD="$( openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)"

# smtp properties
export SMTP_HOST="localhost"
export SMTP_USER=""
export SMTP_PORT=""
export SMTP_PASSWORD=""
export SMTP_AUTH=""
export SMTP_FROM=""
export SMTP_STARTTLS="TRUE"

