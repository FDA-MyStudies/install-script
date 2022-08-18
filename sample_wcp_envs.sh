#!/usr/bin/env bash

# Required - Skip these steps from Labkey-install script - so we can use common functions from labkey-install script
export LABKEY_INSTALL_SKIP_MAIN=1
export LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_EMBEDDED_STEP=1

# general path configuration settings
export LABKEY_APP_HOME="/labkey"
export LABKEY_FILES_ROOT="/labkey/labkey/files"
export LABKEY_LOG_DIR="/labkey/apps/tomcat/logs"
export LABKEY_CONFIG_DIR="/labkey/apps/tomcat/config"
export TOMCAT_INSTALL_HOME="${LABKEY_APP_HOME}/apps/tomcat"
export TOMCAT_INSTALL_TYPE="Standard"
export TOMCAT_TMP_DIR="${TOMCAT_TMP_DIR:-${LABKEY_APP_HOME}/tomcat-tmp}"

# mysql server type defaults to use remote mysql instance this setting enables local mysql server
export MYSQL_SVR_LOCAL="TRUE"

# If no passwords are supplied the install script generates passwords - which can cause password de-sync issues if the install fails
# supplying them here can help overcome those types of issues
#export MYSQL_PASSWORD="your_complex_password_here"
#export MYSQL_ROOT_PASSWORD="your_complex_password_here"

export SMTP_PORT="25"
export SMTP_HOST="localhost"
# initial WCP Admin user  set to email box you control and use forgot password to reset password for initial login
export WCP_ADMIN_EMAIL="donotreply@labkey.com"
export WCP_FEEDBACK_EMAIL="donotreply@labkey.com"
export WCP_CONTACT_EMAIL="donotreply@labkey.com"
export WCP_APP_ENV="uat"
export WCP_PRIVACY_POLICY_URL="https://www.fda.gov/AboutFDA/AboutThisWebsite/WebsitePolicies/#privacy"
export WCP_TERMS_URL="https://www.fda.gov/AboutFDA/AboutThisWebsite/WebsitePolicies/"
export WCP_HOSTNAME="localhost:8443"
