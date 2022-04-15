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

if [ -n "${DEBUG:-}" ]; then
  set -x
fi

# bash strict mode
set -euo pipefail

#
# "Global" variables
#
PRODUCT='WCP Server'
LABKEY_INSTALL_SCRIPT_PATH="${LABKEY_INSTALL_SCRIPT_PATH:-./install-labkey.bash}"

# required to "import" functions & common install steps
# shellcheck source=./install-labkey.bash
# shellcheck disable=SC1091
SKIP_MAIN=1 source "${LABKEY_INSTALL_SCRIPT_PATH}"

#
# Internal Utility Functions
#
function _skip_step() {
  local step_name="$1"

  if ! eval "[ -z \"\${WCP_INSTALL_SKIP_${step_name^^}_STEP:-}\" ]"; then
    echo "skipping '${step_name}' step"
  else
    return 1
  fi
}

function step_intro() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  printf '%s\n\n%s\n\n' \
    "
    ${PRODUCT} CLI Install Script
  " \
    '
    #     #  #####  ######      #####
    #  #  # #     # #     #    #     # ###### #####  #    # ###### #####
    #  #  # #       #     #    #       #      #    # #    # #      #    #
    #  #  # #       ######      #####  #####  #    # #    # #####  #    #
    #  #  # #       #                # #      #####  #    # #      #####
    #  #  # #     # #          #     # #      #   #   #  #  #      #   #
     ## ##   #####  #           #####  ###### #    #   ##   ###### #    #
 '

}

function step_wcp_default_envs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  WCP_APP_ENV="${WCP_APP_ENV:-uat}"
  WCP_CONTACT_EMAIL="${WCP_CONTACT_EMAIL:-donotreply@domain.com}"
  WCP_FEEDBACK_EMAIL="${WCP_FEEDBACK_EMAIL:-donotreply@domain.com}"
  WCP_FROM_EMAIL="${WCP_FROM_EMAIL:-donotreply@domain.com}"
  WCP_ADMIN_FIRSTNAME="${WCP_ADMIN_FIRSTNAME:-WCP}"
  WCP_ADMIN_LASTNAME="${WCP_ADMIN_LASTNAME:-Administrator}"
  WCP_ADMIN_EMAIL="${WCP_ADMIN_EMAIL:-donotreply@domain.com}"
  WCP_HOSTNAME="${WCP_HOSTNAME:-localhost:8443}"
  WCP_PRIVACY_POLICY_URL="${WCP_PRIVACY_POLICY_URL:-}"
  WCP_REGISTRATION_URL="${WCP_REGISTRATION_URL:-reg.localhost}"
  WCP_TERMS_URL="${WCP_TERMS_URL:-}"
  WCP_DIST_URL="${WCP_DIST_URL:-https://github.com/FDA-MyStudies/WCP/releases/download/21.7.1/wcp_full-21.7.1-8.zip}"
  WCP_DIST_FILENAME="${WCP_DIST_FILENAME:-wcp_full-21.7.1-8.zip}"
  WCP_SQL_SCRIPT_URL="${WCP_SQL_SCRIPT_URL:-https://raw.githubusercontent.com/FDA-MyStudies/WCP/develop/sqlscript/HPHC_My_Studies_DB_Create_Script.sql}"
  WCP_SQL_FILENAME="${WCP_SQL_FILENAME:-My_Studies_DB_Create_Script.sql}"

  WCP_LABKEY_APP_TOKEN="${WCP_LABKEY_APP_TOKEN:-00000000-0000-0000-0000-000000000000}"
  WCP_LABKEY_BUNDLE_ID="${WCP_LABKEY_BUNDLE_ID:-com.labkey.abc}"
  WCP_ANDROID_APP_TOKEN="${WCP_ANDROID_APP_TOKEN:-00000000-0000-0000-0000-000000000000}"
  WCP_ANDROID_BUNDLE_ID="${WCP_ANDROID_BUNDLE_ID:-1234567890}"
  WCP_IOS_APP_TOKEN="${WCP_IOS_APP_TOKEN:-00000000-0000-0000-0000-000000000000}"
  WCP_IOS_BUNDLE_ID="${WCP_IOS_BUNDLE_ID:-1234567890}"

  WCP_APP_CUST_SERVE_EMAIL="${WCP_APP_CUST_SERVE_EMAIL:-donotreply@domain.com}"
  WCP_APP_SERVER_SHUTDOWN_EMAIL="${WCP_APP_SERVER_SHUTDOWN_EMAIL:-donotreply@domain.com}"
  WCP_APP_AUDIT_FAIL_EMAIL="${WCP_APP_AUDIT_FAIL_EMAIL:-donotreply@domain.com}"
  WCP_APP_NOTIFY_TITLE="${WCP_APP_NOTIFY_TITLE:-MyStudies}"
  WCP_APP_EMAIL_TITLE="${WCP_APP_EMAIL_TITLE:- The MyStudies Platform Team}"

  MYSQL_HOST="${MYSQL_HOST:-localhost}"
  MYSQL_DB="${MYSQL_DB:-wcp_db}"
  MYSQL_USER="${MYSQL_USER:-app}"
  MYSQL_SVR_LOCAL="${MYSQL_SVR_LOCAL:-FALSE}"
  MYSQL_PORT="${MYSQL_PORT:-3306}"

  # both passwords below must meet MySQL's default complexity requirements
  # Generate password if none is provided
  MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
  MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"

  if [ -n "${DEBUG:-}" ]; then
    env | sort
  fi
}

function step_wcp_required_envs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  local ret=0

  for key in \
    MYSQL_PASSWORD \
    MYSQL_ROOT_PASSWORD; do
    local value
    value="$(env | grep -s "$key" || true)"

    if [ -z "${value%%=*}" ]; then
      echo "value required for \$${key}"
      export ret=1
    fi
  done

  return "$ret"
}

function step_wcp_create_required_paths() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  # directories needed for tomcat service
  create_req_dir "${LABKEY_APP_HOME}"
  create_req_dir "${LABKEY_SRC_HOME}"
  create_req_dir "${LABKEY_INSTALL_HOME}"
  create_req_dir "${TOMCAT_INSTALL_HOME}"
  create_req_dir "${TOMCAT_KEYSTORE_BASE_PATH}"
  create_req_dir "${TOMCAT_TMP_DIR}"
  create_req_dir "${LABKEY_LOG_DIR}"
  create_req_dir "${LABKEY_CONFIG_DIR}"

}

function step_create_wcp_properties() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if [ ! -f "${TOMCAT_INSTALL_HOME}/conf/wcp.properties" ]; then
    # create wcp.properties file
    NewFile="${TOMCAT_INSTALL_HOME}/conf/wcp.properties"
    (
      /bin/cat <<-WCP_PROPS_HERE
				# WCP Properties

				#Email Configuration local
				from.email.address=${WCP_FROM_EMAIL}
				smtp.portvalue=${SMTP_PORT}
				smtp.hostname=${SMTP_HOST}
				sslfactory.value=javax.net.ssl.SSLSocketFactory

				#File Conf
				fda.imgUploadPath=${TOMCAT_INSTALL_HOME}/webapps/fdaResources/
				# fda.currentPath=catalina.home
				fda.imgDisplaydPath=/fdaResources/

				#Email Conf
				acceptLinkMail=https://${WCP_HOSTNAME}/fdahpStudyDesigner/createPassword.do?securityToken=
				login.url=https://${WCP_HOSTNAME}/fdahpStudyDesigner/login.do
				signUp.url=https://${WCP_HOSTNAME}/fdahpStudyDesigner/signUp.do?securityToken=
				emailChangeLink=https://${WCP_HOSTNAME}/fdahpStudyDesigner/validateSecurityToken.do?securityToken=

				#DB Conf
				db.url=${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}?autoReconnect=true&sslMode=PREFERRED&enabledTLSProtocols=TLSv1.2
				db.username=${MYSQL_USER}
				db.password=${MYSQL_PASSWORD}

				#DB Conf for WS hibernate
				hibernate.connection.url=jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}?autoReconnect=true&sslMode=PREFERRED&enabledTLSProtocols=TLSv1.2
				hibernate.connection.username=${MYSQL_USER}
				hibernate.connection.password=${MYSQL_PASSWORD}

				#Study Image/Log Path
				fda.smd.study.thumbnailPath=https://${WCP_HOSTNAME}/fdaResources/studylogo/
				fda.smd.study.pagePath=https://${WCP_HOSTNAME}/fdaResources/studypages/
				fda.smd.resource.pdfPath=https://${WCP_HOSTNAME}/fdaResources/studyResources/

				#Terms and Privacy policy path
				fda.smd.pricaypolicy=${WCP_PRIVACY_POLICY_URL}
				fda.smd.terms=${WCP_TERMS_URL}

				#Study Questionnaire Image/Log Path
				fda.smd.questionnaire.image=https://${WCP_HOSTNAME}/fdaResources/questionnaire/
				fda.smd.gatewayResource.pdfPath=https://${WCP_HOSTNAME}/fdaResources/gatewayResource/App_Glossary.pdf

				#Feedback and Contact Us for from email
				fda.smd.feedback=${WCP_FEEDBACK_EMAIL}
				fda.smd.contactus=${WCP_CONTACT_EMAIL}

				#App Environment -- > possible value : local / uat / prod
				fda.env=${WCP_APP_ENV}

				#Fda Audit Logs
				fda.logFilePath=${LABKEY_LOG_DIR}/
				fda.logFileIntials=auditLogs

				#FDA registration server root URL
				fda.registration.root.url=https://${WCP_REGISTRATION_URL}

				#App Email Address
				email.address.customer.service=${WCP_APP_CUST_SERVE_EMAIL}
				email.address.server.shutdown=${WCP_APP_SERVER_SHUTDOWN_EMAIL}
				email.address.audit.failure=${WCP_APP_AUDIT_FAIL_EMAIL}

				#APP MESSAGE PROPERTIES
				fda.smd.notification.title=${WCP_APP_NOTIFY_TITLE}
				fda.smd.email.title=${WCP_APP_EMAIL_TITLE}

WCP_PROPS_HERE
    ) >"$NewFile"
    chmod 600 "${TOMCAT_INSTALL_HOME}/conf/wcp.properties"
    chown "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${TOMCAT_INSTALL_HOME}/conf/wcp.properties"

  else
    console_msg "Warning: The wcp.properties file already exists at ${TOMCAT_INSTALL_HOME}/conf/wcp.properties you may want to verify its contents."
  fi

}

function step_create_context_xml() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if [ -f "${TOMCAT_INSTALL_HOME}/conf/context.xml" ]; then
    # remove default context.xml
    rm -f "${TOMCAT_INSTALL_HOME}/conf/context.xml"
    # create context.xml
    NewFile="${TOMCAT_INSTALL_HOME}/conf/context.xml"
    (
      /bin/cat <<CONTEXT_HERE
<?xml version='1.0' encoding='utf-8'?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
<!-- The contents of this file will be loaded for each web application -->
<Context>

    <!-- Default set of monitored resources. If one of these changes, the    -->
    <!-- web application will be reloaded.                                   -->
    <WatchedResource>WEB-INF/web.xml</WatchedResource>
    <WatchedResource>\${catalina.base}/conf/web.xml</WatchedResource>

    <!-- Uncomment this to disable session persistence across Tomcat restarts -->
    <!--
    <Manager pathname="" />
    -->

    <!-- Uncomment this to enable Comet connection tacking (provides events
         on session expiration as well as webapp lifecycle) -->
    <!--
    <Valve className="org.apache.catalina.valves.CometConnectionManagerValve" />
    -->
    <Parameter name="property_file_location_prop" value="${TOMCAT_INSTALL_HOME}/conf/" override="1"/>
    <Parameter name="property_file_name" value="wcp" override="1"/>
    <Parameter name="property_file_location_config" value="file:${TOMCAT_INSTALL_HOME}/conf/wcp.properties" override="1"/>
    <Parameter name="property_file_location_path" value="${TOMCAT_INSTALL_HOME}/conf/wcp.properties" override="1"/>
    <Parameter name="authorizationResource_file_location_path" value="${TOMCAT_INSTALL_HOME}/conf/authorizationResource.properties" override="1"/>
</Context>

CONTEXT_HERE
    ) >"$NewFile"

    chmod 600 "${TOMCAT_INSTALL_HOME}/conf/context.xml"
    chown "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${TOMCAT_INSTALL_HOME}/conf/context.xml"

  fi

}

function step_create_fdaresources_xml() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # rename labkey ROOT.xml as its not needed
  if [ -f "${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/ROOT.xml" ]; then
    mv "${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/ROOT.xml" "${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/ROOT.xml.bak"
  fi

  if [ ! -f "${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/fdaResources.xml" ]; then
    # create fdaResources.xml file
    NewFile="${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/fdaResources.xml"
    (
      /bin/cat <<FDARESOURCE_HERE
<Context docBase="${TOMCAT_INSTALL_HOME}/webapps/fdaResources" debug="0" reloadable="true" crossContext="true">
</Context>
FDARESOURCE_HERE
    ) >"$NewFile"

    chmod 600 "${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/fdaResources.xml"
    chown "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/fdaResources.xml"

  else
    console_msg "Warning: The fdaResources.xml file already exists at ${TOMCAT_INSTALL_HOME}/conf/Catalina/localhost/fdaResources.xml you may want to verify its contents."
  fi

}

function step_create_auth_properties() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # skip creation of authorizationResources.properties file if it already exists
  if [ -f "${TOMCAT_INSTALL_HOME}/conf/authorizationResource.properties" ]; then
    console_msg "WARNING: The authorizationResource.properties exists at ${TOMCAT_INSTALL_HOME}/conf/authorizationResource.properties - you may want to verify its contents."
    return 0
  fi

  if [ ! -f "${TOMCAT_INSTALL_HOME}/conf/authorizationResource.properties" ]; then
    # create authorizationResources.properties file using env vars
    NewFile="${TOMCAT_INSTALL_HOME}/conf/authorizationResource.properties"
    (
      /bin/cat <<-AUTH_PROPERTIES_HERE
				############################# AUTHORIZATION DETAILS #############################
				$WCP_LABKEY_APP_TOKEN=labkey.apptoken
				$WCP_LABKEY_BUNDLE_ID=labkey.bundleid

				$WCP_ANDROID_APP_TOKEN=android.apptoken
				$WCP_ANDROID_BUNDLE_ID=android.bundleid

				$WCP_IOS_APP_TOKEN=ios.apptoken
				$WCP_IOS_BUNDLE_ID=ios.bundleid

				AUTH_PROPERTIES_HERE
    ) >"$NewFile"

    chmod 600 "${TOMCAT_INSTALL_HOME}/conf/authorizationResource.properties"
    chown "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${TOMCAT_INSTALL_HOME}/conf/authorizationResource.properties"
  fi

}

function step_mysql_config() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # shellcheck disable=SC2016
  echo 'WARNING: $MYSQL_PASSWORD & $MYSQL_ROOT_PASSWORD must meet complexity requirements and be shell-safe'
  echo 'WARNING: MySQL password complexity requirements set to "MEDIUM" by default'

  case "_$(platform)" in
  _amzn)

    if [ "$MYSQL_SVR_LOCAL" == "TRUE" ]; then
      # MySQL repo
      sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
      #amazon-linux-extras install epel
      sudo amazon-linux-extras enable epel
      sudo yum clean metadata
      sudo yum update -y
      sudo yum install epel-release -y
      sudo yum install tomcat-native.x86_64 apr fontconfig mysql-community-server -y

      sudo systemctl enable mysqld
      sudo systemctl start mysqld
      # Do some mysql user stuff here
      local mysqlrootpw
      mysqlrootpw=$(sudo grep 'temporary password' /var/log/mysqld.log | tail -c14 | cut -f1 | tr -d "\n" | tr -d "[:space:]")
      echo "mysql temporary password is:$mysqlrootpw"
      mysqladmin -u root -p"${mysqlrootpw}" password "$MYSQL_ROOT_PASSWORD"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE ${MYSQL_DB} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER ${MYSQL_USER}@localhost IDENTIFIED BY '${MYSQL_PASSWORD}';"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "ALTER USER ${MYSQL_USER}@localhost PASSWORD EXPIRE NEVER;"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost';"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
      console_msg "MYSQL Server and Client Installed ..."

    else
      sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
      #amazon-linux-extras install epel
      sudo amazon-linux-extras enable epel
      sudo yum clean metadata
      sudo yum install epel-release mysql-community-client -y
      sudo yum install tomcat-native.x86_64 apr fontconfig -y
      console_msg "MYSQL Client Installed ..."
    fi
    ;;

  _centos)
    if [ "$MYSQL_SVR_LOCAL" == "TRUE" ]; then
      # MySQL repo
      sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
      sudo yum clean metadata
      sudo yum update -y
      sudo yum install epel-release unzip -y
      sudo yum install tomcat-native.x86_64 apr fontconfig mysql-community-server -y

      sudo systemctl enable mysqld
      sudo systemctl start mysqld
      # Do some mysql user stuff here
      local mysqlrootpw
      mysqlrootpw=$(sudo grep 'temporary password' /var/log/mysqld.log | tail -c14 | cut -f1 | tr -d "\n" | tr -d "[:space:]")
      echo "mysql temporary password is:$mysqlrootpw"
      mysqladmin -u root -p"${mysqlrootpw}" password "$MYSQL_ROOT_PASSWORD"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE ${MYSQL_DB} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER ${MYSQL_USER}@localhost IDENTIFIED BY '${MYSQL_PASSWORD}';"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "ALTER USER ${MYSQL_USER}@localhost PASSWORD EXPIRE NEVER;"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost';"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
      console_msg "MYSQL Server and Client Installed ..."

    else
      sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
      sudo yum clean metadata
      sudo yum install epel-release mysql-community-client unzip -y
      sudo yum install tomcat-native.x86_64 apr fontconfig -y
      console_msg "MYSQL Client Installed ..."
    fi
    ;;

  _ubuntu)

    if [ "$MYSQL_SVR_LOCAL" == "TRUE" ]; then

      # get mysql repo
      wget https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb
      sudo DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.22-1_all.deb
      # force update after repo add
      sudo apt update

      sudo DEBIAN_FRONTEND=noninteractive apt -y install -f unzip mysql-client mysql-server

      sudo systemctl enable mysql.service
      sudo systemctl start mysql.service
      # Do some mysql user stuff here

      mysqladmin -u root password "$MYSQL_ROOT_PASSWORD"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE ${MYSQL_DB} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER ${MYSQL_USER}@localhost IDENTIFIED BY '${MYSQL_PASSWORD}';"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "ALTER USER ${MYSQL_USER}@localhost PASSWORD EXPIRE NEVER;"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost';"
      mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
      console_msg "MYSQL Server and Client Installed ..."

    else
      wget https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb
      sudo DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.22-1_all.deb
      sudo apt-get update
      sudo apt-get -y install -f unzip mysql-client
      console_msg "MYSQL Client Installed ..."
    fi

    ;;

  _*)
    echo "can't install mysql on unrecognized platform: \"$(platform)\""
    ;;
  esac

}

function step_download_wcp_dist() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  local ret=0

  # download wcp distribution
  cd "$LABKEY_SRC_HOME" || exit
  if [ ! -s "${LABKEY_APP_HOME}/src/labkey/${WCP_DIST_FILENAME}" ]; then
    wget -N "$WCP_DIST_URL"
  fi

  if [ -s "${LABKEY_APP_HOME}/src/labkey/${WCP_DIST_FILENAME}" ]; then
    unzip "$WCP_DIST_FILENAME"
    chown "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${LABKEY_APP_HOME}/src/labkey/"*.war
    cp -a "${LABKEY_APP_HOME}/src/labkey/StudyMetaData-"*.war "${TOMCAT_INSTALL_HOME}/webapps/StudyMetaData.war"
    cp -a "${LABKEY_APP_HOME}/src/labkey/fdahpStudyDesigner-"*.war "${TOMCAT_INSTALL_HOME}/webapps/fdahpStudyDesigner.war"
    cp -a "${LABKEY_APP_HOME}/src/labkey/fdaResources.war" "${TOMCAT_INSTALL_HOME}/webapps/"
    console_msg "WCP Distribution successfully downloaded and installed."
  else
    # fail if download fails or dist file is 0 bytes
    console_msg "ERROR: WCP distribution file: ${LABKEY_APP_HOME}/src/labkey/${WCP_DIST_FILENAME} failed to download correctly! Exiting..."
    export ret=1
  fi

  return "$ret"

}

function step_initialize_wcp_database() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  local ret=0

  # download wcp sql create script
  cd "$LABKEY_SRC_HOME" || exit
  if [ ! -s "${LABKEY_APP_HOME}/src/labkey/${WCP_SQL_FILENAME}" ]; then
    wget "$WCP_SQL_SCRIPT_URL" -O "${WCP_SQL_FILENAME}"
    # replace fda_hphc db name with MYSQL_DB name
    sed -i -e "s/fda_hphc/${MYSQL_DB}/g" "${WCP_SQL_FILENAME}"
    # replace default root user in script with MYSQL_USER
    sed -i -e "s/root/${MYSQL_USER}/g" "${WCP_SQL_FILENAME}"
    sed -i -e "s/localhost/%/g" "${WCP_SQL_FILENAME}"
    # replace default wcp admin user info with WCP_ADMIN_* vars
    sed -i -e "s/Account/${WCP_ADMIN_FIRSTNAME}/g" "${WCP_SQL_FILENAME}"
    sed -i -e "s/Manager/${WCP_ADMIN_LASTNAME}/g" "${WCP_SQL_FILENAME}"
    sed -i -e "s/your email address/${WCP_ADMIN_EMAIL}/g" "${WCP_SQL_FILENAME}"

    # initialize the database
    mysql -h "${MYSQL_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DB}" <"${LABKEY_APP_HOME}/src/labkey/${WCP_SQL_FILENAME}"
    console_msg "WCP Database Initialized successfully."

  else
    # fail if download fails or sql file is 0 bytes
    console_msg "ERROR: The WCP SQL Initialize script : ${LABKEY_APP_HOME}/src/labkey/${WCP_SQL_FILENAME} failed to download correctly! Exiting..."
    export ret=1
  fi

  return "$ret"

}

function step_start_wcp() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  # Enables the tomcat service and starts wcp
  sudo systemctl enable tomcat_lk.service
  sudo systemctl start tomcat_lk.service
}

function step_wcp_outro() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  echo "
    Thank you for installing MyStudies WCP Server!

    You may login to the installed WCP from ${LABKEY_BASE_SERVER_URL:-}:${LABKEY_PORT:-}/fdahpStudyDesigner/login.do

    You may test to see if the other WCP services respond with these URLs:
       curl -k ${LABKEY_BASE_SERVER_URL:-}:${LABKEY_PORT:-}/StudyMetaData/ping
       curl -k ${LABKEY_BASE_SERVER_URL:-}:${LABKEY_PORT:-}/fdaResources/

    Logs are available at: ${TOMCAT_INSTALL_HOME}/logs/
  "
}

#
# Main loop
#
function main() {
  step_intro

  step_check_if_root

  console_msg "Importing default environment variables from install-labkey.bash"
  # use default envs from labkey-install script
  step_default_envs
  step_wcp_default_envs

  step_wcp_required_envs

  console_msg "Installing Operating System dependencies"
  step_os_prereqs
  console_msg "Creating required paths"
  step_wcp_create_required_paths
  console_msg "Configuring Tomcat user"
  step_tomcat_user

  console_msg "Configuring Self Signed Certificate"
  step_tomcat_cert
  console_msg "Configuring Standard Tomcat Service"
  step_tomcat_service_standard
  console_msg "Creating wcp.properties"
  step_create_wcp_properties
  console_msg "Creating tomcat context.xml"
  step_create_context_xml
  console_msg "Creating fdaResources.xml"
  step_create_fdaresources_xml
  console_msg "Creating authorizationResource.properties"
  step_create_auth_properties
  console_msg "Creating Alt files path links"
  step_alt_files_link
  console_msg "Configuring MySQL"
  step_mysql_config
  console_msg "Downloading WCP distribution"
  step_download_wcp_dist
  console_msg "Initializing the WCP Database"
  step_initialize_wcp_database
  console_msg "Starting WCP Services"
  step_start_wcp
  console_msg "Installation completed"
  step_wcp_outro

}

# Main function called here
if [ -z "${SKIP_MAIN:-}" ]; then
  main
fi
