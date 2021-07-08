#!/usr/bin/env bash

# Configure the env vars to use for the installer

export ADOPTOPENJDK_VERSION="adoptopenjdk-16-hotspot"
export LABKEY_COMPANY_NAME="LabKey"
export LABKEY_SYSTEM_DESCRIPTION="labkey demo deployment"
export LABKEY_SYSTEM_EMAIL_ADDRESS="donotreply@labkey.com"
export LABKEY_SYSTEM_SHORT_NAME="demo"
export LABKEY_DEFAULT_DOMAIN="labkey.com"
export LABKEY_BASE_SERVER_URL="http://localhost"
export LABKEY_FILES_ROOT="/labkey/files"

export LABKEY_VERSION="21.6.0"
export LABKEY_DISTRIBUTION="community"

# tomcat properties

export LABKEY_APP_HOME="/tmp/labkey"
export LABKEY_INSTALL_HOME="$LABKEY_APP_HOME/labkey"

export LABKEY_SRC_HOME="$LABKEY_APP_HOME/src/labkey"

# tomcat properties used in application.properties
export LOG_LEVEL_TOMCAT="OFF"
export LOG_LEVEL_SPRING_WEB="OFF"
export LOG_LEVEL_SQL="OFF"
# shellcheck disable=SC2155
export TOMCAT_KEYSTORE_PASSWORD="$(openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)"
export TOMCAT_INSTALL_HOME="$LABKEY_APP_HOME/apps/tomcat"
export TOMCAT_TIMEZONE="America/Los_Angeles"
export CATALINA_HOME="$TOMCAT_INSTALL_HOME"
export TOMCAT_USERNAME="tomcat"
export TOMCAT_UID=3000
export TOMCAT_KEYSTORE_FILENAME="keystore.tomcat.p12"
export TOMCAT_KEYSTORE_ALIAS="tomcat"
export CERT_C="US"
export CERT_ST="Washington"
export CERT_L="Seattle"
export CERT_O="${LABKEY_COMPANY_NAME}"
export CERT_OU="IT"
export CERT_CN="localhost"

export JAVA_HEAP_SIZE="4G"
# shellcheck disable=SC2155
export LABKEY_MEK="$(openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)"
# shellcheck disable=SC2155
export LABKEY_GUID=$(uuidgen)

# postgres properties
export POSTGRES_HOST="localhost"
export POSTGRES_DB="labkey"
export POSTGRES_USER="labkey"
# shellcheck disable=SC2155
export POSTGRES_PASSWORD="$(openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)"
export POSTGRES_SVR_LOCAL="FALSE"

# smtp properties
export SMTP_HOST="localhost"
export SMTP_USER=""
export SMTP_PORT=""
export SMTP_PASSWORD=""
export SMTP_AUTH=""
export SMTP_FROM=""
export SMTP_STARTTLS="TRUE"

export LABKEY_INSTALL_SKIP_STEP_START_LABKEY=1
export LABKEY_PORT="8443"
