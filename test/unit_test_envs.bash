#!/usr/bin/env bash
# Mock envs for unit testing

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

# Mock passwords used for unit tests only
export TOMCAT_KEYSTORE_PASSWORD="vbzYdXVHEOMyHQpktMECzOnm703yUJon"
export LABKEY_MEK="d0NCCzLImuDXGVtM6cxrJ3X4nX9za4Wt"
export LABKEY_GUID="B09EC7A3-FC20-44F8-A8D6-86EFF6966B45"
export POSTGRES_PASSWORD="yvKBszNG1xWIxGy54OfbXehovKlA4GXn"
export SMTP_PASSWORD="h4EVkqgND3pPDfMoHh018h8n8aSobHs2"

# postgres properties
export POSTGRES_HOST="localhost"
export POSTGRES_DB="labkey"
export POSTGRES_USER="labkey"

# smtp properties
export SMTP_HOST="localhost"
export SMTP_USER=""
export SMTP_PORT=""
export SMTP_AUTH=""
export SMTP_FROM=""
export SMTP_STARTTLS="TRUE"
