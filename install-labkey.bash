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
PRODUCT='LabKey Server'

#
# Internal Utility Functions
#
function _skip_step() {
  local step_name="$1"

  if ! eval "[ -z \"\${LABKEY_INSTALL_SKIP_${step_name^^}_STEP:-}\" ]"; then
    echo "skipping '${step_name}' step"
  else
    return 1
  fi
}

function _os_release() {
  grep -s "^${1}=" "${SHUNIT_TMPDIR:-/etc}/os-release" | cut -d'=' -f2- |
    tr -d '\n' | tr -d '"' | tr -d \' | xargs | tr '[:upper:]' '[:lower:]'
}

function _lsb_release() {
  local flag="$1"

  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -s "-${flag}" | tr '[:upper:]' '[:lower:]'
  fi
}

function platform() {
  local primary
  local secondary

  primary="$(_os_release 'ID' || true)"
  secondary="$(_lsb_release 'i')"

  if [ -n "$primary" ]; then
    echo "$primary"
  else
    if [[ $secondary == 'amazon' ]]; then
      echo 'amzn'
    else
      echo "$secondary"
    fi
  fi | xargs
}

function platform_version() {
  local primary
  local secondary

  primary="$(_os_release 'VERSION_ID' || true)"
  secondary="$(_lsb_release 'r')"

  if [ -n "$primary" ]; then
    echo "$primary"
  else
    echo "$secondary"
  fi | xargs
}

function console_msg() {
  bold=$'\033[1m'
  normal=$'\033[0m'
  echo "${normal}---------${bold} $1 ${normal}---------"
}

function create_req_dir() {
  echo "     checking to see if required directory $1 exists..."
  if [ "$1" == "" ]; then
    echo "     ERROR - you must supply a directory name"
  else
    if [ ! -d "$1" ]; then
      echo "     creating $1"
      mkdir -p "$1"
    else
      echo "       required directory $1 exists..."
    fi
  fi
}

#
# Install Steps
#
function step_intro() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  printf '%s\n\n%s\n\n' \
    "
    ${PRODUCT} CLI Install Script
  " \
    '
     __
     ||  |  _ |_ |/ _
    (__) |_(_||_)|\(/_\/
                      /'
}

function step_check_if_root() {
  # must be root or launch script with sudo
  if [[ $(whoami) != root ]]; then
    echo Please run this script as root or using sudo
    return 1
  fi
}

function step_default_envs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # Provides default values for environment variables - override these values by passing in your own values via
  # environment variables in the shell used to launch this script.

  # Java env vars
  ADOPTOPENJDK_VERSION="${ADOPTOPENJDK_VERSION:-temurin-17-jdk}"

  # set default heap min/max to 50% (w/ <= 8G) or 75% of total mem
  DEFAULT_JAVA_HEAP_SIZE="$(
    total="$(free -m | grep ^Mem | tr -s ' ' | cut -d ' ' -f 2)"

    if [ "$total" -ge 8192 ]; then
      heap_modifier='75'
    else
      heap_modifier='50'
    fi

    echo -n "$((total * heap_modifier / 100))M"
  )"

  JAVA_HEAP_SIZE="${JAVA_HEAP_SIZE:-${DEFAULT_JAVA_HEAP_SIZE}}"

  # LabKey env vars
  LABKEY_COMPANY_NAME="${LABKEY_COMPANY_NAME:-LabKey}"
  LABKEY_SYSTEM_DESCRIPTION="${LABKEY_SYSTEM_DESCRIPTION:-labkey demo deployment}"
  LABKEY_SYSTEM_SHORT_NAME="${LABKEY_SYSTEM_SHORT_NAME:-demo}"
  LABKEY_DEFAULT_DOMAIN="${LABKEY_DEFAULT_DOMAIN:-labkey.com}"
  LABKEY_SYSTEM_EMAIL_ADDRESS="${LABKEY_SYSTEM_EMAIL_ADDRESS:-donotreply@${LABKEY_DEFAULT_DOMAIN}}"
  LABKEY_BASE_SERVER_URL="${LABKEY_BASE_SERVER_URL:-https://localhost}"
  LABKEY_APP_HOME="${LABKEY_APP_HOME:-/labkey}"
  LABKEY_INSTALL_HOME="${LABKEY_INSTALL_HOME:-$LABKEY_APP_HOME/labkey}"
  LABKEY_SRC_HOME="${LABKEY_SRC_HOME:-$LABKEY_APP_HOME/src/labkey}"
  LABKEY_FILES_ROOT="${LABKEY_FILES_ROOT:-${LABKEY_INSTALL_HOME}/files}"
  LABKEY_VERSION="${LABKEY_VERSION:-21.7.0}"
  LABKEY_BUILD="${LABKEY_BUILD:-2}"
  LABKEY_DISTRIBUTION="${LABKEY_DISTRIBUTION:-community}"
  LABKEY_DIST_BUCKET="${LABKEY_DIST_BUCKET:-lk-binaries}"
  LABKEY_DIST_REGION="${LABKEY_DIST_REGION:-us-west-2}"
  LABKEY_DIST_URL="${LABKEY_DIST_URL:-https://${LABKEY_DIST_BUCKET}.s3.${LABKEY_DIST_REGION}.amazonaws.com/downloads/release/${LABKEY_DISTRIBUTION}/${LABKEY_VERSION}/LabKey${LABKEY_VERSION}-${LABKEY_BUILD}-${LABKEY_DISTRIBUTION}-embedded.tar.gz}"
  LABKEY_DIST_FILENAME="${LABKEY_DIST_FILENAME:-LabKey${LABKEY_VERSION}-${LABKEY_BUILD}-${LABKEY_DISTRIBUTION}-embedded.tar.gz}"
  LABKEY_DIST_DIR="${LABKEY_DIST_DIR:-${LABKEY_DIST_FILENAME::-16}}"
  LABKEY_HTTPS_PORT="${LABKEY_HTTPS_PORT:-8443}"
  LABKEY_HTTP_PORT="${LABKEY_HTTP_PORT:-8080}"
  LABKEY_LOG_DIR="${LABKEY_LOG_DIR:-${LABKEY_INSTALL_HOME}/logs}"
  LABKEY_CONFIG_DIR="${LABKEY_CONFIG_DIR:-${LABKEY_INSTALL_HOME}/config}"
  LABKEY_EXT_MODULES_DIR="${LABKEY_EXT_MODULES_DIR:-${LABKEY_INSTALL_HOME}/externalModules}"
  LABKEY_STARTUP_DIR="${LABKEY_STARTUP_DIR:-${LABKEY_INSTALL_HOME}/server/startup}"
  # Generate MEK and GUID if none is provided
  LABKEY_MEK="${LABKEY_MEK:-$(openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)}"
  LABKEY_GUID="${LABKEY_GUID:-$(uuidgen)}"

  # Tomcat env vars
  TOMCAT_INSTALL_TYPE="${TOMCAT_INSTALL_TYPE:-Embedded}"
  TOMCAT_INSTALL_HOME="${TOMCAT_INSTALL_HOME:-$LABKEY_INSTALL_HOME}"
  TOMCAT_TIMEZONE="${TOMCAT_TIMEZONE:-America/Los_Angeles}"
  TOMCAT_TMP_DIR="${TOMCAT_TMP_DIR:-${LABKEY_APP_HOME}/tomcat-tmp}"
  TOMCAT_LIB_PATH="${TOMCAT_LIB_PATH:-/usr/lib64}"
  CATALINA_HOME="${CATALINA_HOME:-$TOMCAT_INSTALL_HOME}"
  TOMCAT_USERNAME="${TOMCAT_USERNAME:-tomcat}"
  TOMCAT_UID="${TOMCAT_UID:-3000}"
  TOMCAT_KEYSTORE_BASE_PATH="${TOMCAT_KEYSTORE_BASE_PATH:-$TOMCAT_INSTALL_HOME/SSL}"
  TOMCAT_KEYSTORE_FILENAME="${TOMCAT_KEYSTORE_FILENAME:-keystore.tomcat.p12}"
  TOMCAT_KEYSTORE_ALIAS="${TOMCAT_KEYSTORE_ALIAS:-tomcat}"
  TOMCAT_KEYSTORE_FORMAT="${TOMCAT_KEYSTORE_FORMAT:-PKCS12}"
  TOMCAT_SESSION_TIMEOUT="${TOMCAT_SESSION_TIMEOUT:-30}"

  TOMCAT_SSL_CIPHERS="${TOMCAT_SSL_CIPHERS:-HIGH:!ADH:!EXP:!SSLv2:!SSLv3:!MEDIUM:!LOW:!NULL:!aNULL}"
  TOMCAT_SSL_ENABLED_PROTOCOLS="${TOMCAT_SSL_ENABLED_PROTOCOLS:-TLSv1.3,+TLSv1.2}"
  TOMCAT_SSL_PROTOCOL="${TOMCAT_SSL_PROTOCOL:-TLS}"

  # Used for Standard Tomcat installs only
  TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.65}"
  TOMCAT_URL="http://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
  TOMCAT_USE_PRIVILEGED_PORTS="${TOMCAT_USE_PRIVILEGED_PORTS:-FALSE}"
  TOMCAT_CONTEXT_PATH="${TOMCAT_CONTEXT_PATH:-ROOT}"
  # Used for non-embedded distributions
  LABKEY_INSTALLER_CMD="$LABKEY_SRC_HOME/${LABKEY_DIST_FILENAME::-7}/manual-upgrade.sh -l $LABKEY_INSTALL_HOME/ -d $LABKEY_SRC_HOME/${LABKEY_DIST_FILENAME::-7} -c $TOMCAT_INSTALL_HOME -u $TOMCAT_USERNAME --noPrompt --tomcat_lk --skip_tomcat"

  # Generate password if none is provided
  TOMCAT_KEYSTORE_PASSWORD="${TOMCAT_KEYSTORE_PASSWORD:-$(openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)}"
  CERT_C="${CERT_C:-US}"
  CERT_ST="${CERT_ST:-Washington}"
  CERT_L="${CERT_L:-Seattle}"
  CERT_O="${CERT_O:-${LABKEY_COMPANY_NAME}}"
  CERT_OU="${CERT_OU:-IT}"
  CERT_CN="${CERT_CN:-localhost}"

  # tomcat properties used in application.properties
  LOG_LEVEL_TOMCAT="${LOG_LEVEL_TOMCAT:-OFF}"
  LOG_LEVEL_SPRING_WEB="${LOG_LEVEL_SPRING_WEB:-OFF}"
  LOG_LEVEL_SQL="${LOG_LEVEL_SQL:-OFF}"

  # postgres env vars
  POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
  POSTGRES_DB="${POSTGRES_DB:-labkey}"
  POSTGRES_USER="${POSTGRES_USER:-labkey}"
  POSTGRES_SVR_LOCAL="${POSTGRES_SVR_LOCAL:-FALSE}"
  POSTGRES_PORT="${POSTGRES_PORT:-5432}"
  POSTGRES_PARAMETERS="${POSTGRES_PARAMETERS:-}"
  # Generate password if none is provided
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -base64 64 | tr -dc _A-Z-a-z-0-9 | fold -w 32 | head -n1)}"
  POSTGRES_PROVISION_REMOTE_DB="${POSTGRES_PROVISION_REMOTE_DB:-FALSE}"
  POSTGRES_REMOTE_ADMIN_USER="${POSTGRES_REMOTE_ADMIN_USER:-postgres_admin}"
  POSTGRES_REMOTE_ADMIN_PASSWORD="${POSTGRES_REMOTE_ADMIN_PASSWORD:-}"
  POSTGRES_VERSION="${POSTGRES_VERSION:-}"

  # smtp env vars
  SMTP_HOST="${SMTP_HOST:-localhost}"
  SMTP_USER="${SMTP_USER:-}"
  SMTP_PORT="${SMTP_PORT:-}"
  SMTP_PASSWORD="${SMTP_PORT:-}"
  SMTP_AUTH="${SMTP_AUTH:-}"
  SMTP_FROM="${SMTP_FROM:-}"
  SMTP_STARTTLS="${SMTP_STARTTLS:-TRUE}"

  # ALT File Root env vars
  ALT_FILE_ROOT_HEAD="${ALT_FILE_ROOT_HEAD:-/media/ebs_volume}"
  COOKIE_ALT_FILE_ROOT_HEAD="${COOKIE_ALT_FILE_ROOT_HEAD:-.ebs_volume}"

  if [ -n "${DEBUG:-}" ]; then
    env | sort
  fi
}

function step_required_envs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  local ret=0

  for key in \
    LABKEY_APP_HOME \
    LABKEY_FILES_ROOT \
    LABKEY_COMPANY_NAME \
    LABKEY_SYSTEM_DESCRIPTION \
    LABKEY_BASE_SERVER_URL; do
    local value
    value="$(env | grep -s "$key" || true)"

    if [ -z "${value%%=*}" ]; then
      echo "value required for \$${key}"
      export ret=1
    fi
  done

  return "$ret"
}

function step_create_required_paths() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  # need path to place application.properties file
  create_req_dir "${LABKEY_APP_HOME}"
  create_req_dir "${LABKEY_SRC_HOME}"
  create_req_dir "${LABKEY_INSTALL_HOME}"
  create_req_dir "${TOMCAT_INSTALL_HOME}"
  create_req_dir "${TOMCAT_KEYSTORE_BASE_PATH}"
  create_req_dir "${TOMCAT_TMP_DIR}"
  # directories needed for embedded tomcat builds
  create_req_dir "${LABKEY_LOG_DIR}"
  create_req_dir "${LABKEY_CONFIG_DIR}"
  create_req_dir "${LABKEY_EXT_MODULES_DIR}"
  create_req_dir "${LABKEY_STARTUP_DIR}"
  # TODO not sure if these are needed
  create_req_dir "${TOMCAT_INSTALL_HOME}/lib"
  create_req_dir "/work/Tomcat/localhost/ROOT"
  create_req_dir "/work/Tomcat/localhost/_"

}

function step_os_prereqs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if ! command -v systemctl >/dev/null 2>&1; then
    echo '

      "systemctl" required but not detected!

      This script has not been tested on systems without System D.

    '
  fi

  case "_$(platform)" in
  _amzn)
    # amzn stuff goes here
    # Add adoptium repo
    if [ ! -f "/etc/yum.repos.d/adoptium.repo" ]; then
      NewFile="/etc/yum.repos.d/adoptium.repo"
      (
        /bin/cat <<-AMZN_JDK_HERE
				[Adoptium]
				name=Adoptium
				baseurl=https://packages.adoptium.net/artifactory/rpm/amazonlinux/\$releasever/\$basearch
				enabled=1
				gpgcheck=1
				gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
			AMZN_JDK_HERE
      ) >"$NewFile"
    fi
    sudo yum update -y
    sudo yum install -y "$ADOPTOPENJDK_VERSION"
    ;;

  _almalinux)
    sudo dnf update -y
    sudo dnf install epel-release vim wget -y
    # - set selinux to permissive mode - SELinux Settings for Tomcat are complicated and beyond scope of this script
    console_msg "Checking SELinux Mode...."
    SEL_STATUS="$(/sbin/getenforce)"
    console_msg "SELinux Mode is: $SEL_STATUS..."
    if [[ $SEL_STATUS == "Enforcing" ]]; then
      console_msg "Setting SELinux Status to Permissive"
      sudo /sbin/setenforce 0
      sudo sed -i 's/ELINUX=enforcing/ELINUX=disabled/g' /etc/selinux/config
    fi
    # Add adoptium repo
    if [ ! -f "/etc/yum.repos.d/adoptium.repo" ]; then
      NewFile="/etc/yum.repos.d/adoptium.repo"
      (
        /bin/cat <<-ALMA_JDK_HERE
				[Adoptium]
				name=Adoptium
				baseurl=https://packages.adoptium.net/artifactory/rpm/rhel/\$releasever/\$basearch
				enabled=1
				gpgcheck=1
				gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
			ALMA_JDK_HERE
      ) >"$NewFile"
    fi
    sudo dnf install -y tomcat-native apr fontconfig "$ADOPTOPENJDK_VERSION"
    ;;

  _rhel)
    sudo dnf update -y
    sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    sudo dnf repolist
    sudo dnf install vim wget -y
    # - set selinux to permissive mode - SELinux Settings for Tomcat are complicated and beyond scope of this script
    console_msg "Checking SELinux Mode...."
    SEL_STATUS="$(/sbin/getenforce)"
    console_msg "SELinux Mode is: $SEL_STATUS..."
    if [[ $SEL_STATUS == "Enforcing" ]]; then
      console_msg "Setting SELinux Status to Permissive"
      sudo /sbin/setenforce 0
      sudo sed -i 's/ELINUX=enforcing/ELINUX=disabled/g' /etc/selinux/config
    fi
    # Add adoptium repo
    if [ ! -f "/etc/yum.repos.d/adoptium.repo" ]; then
      NewFile="/etc/yum.repos.d/adoptium.repo"
      (
        /bin/cat <<-RHEL_JDK_HERE
				[Adoptium]
				name=Adoptium
				baseurl=https://packages.adoptium.net/artifactory/rpm/rhel/\$releasever/\$basearch
				enabled=1
				gpgcheck=1
				gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
			RHEL_JDK_HERE
      ) >"$NewFile"
    fi
    sudo dnf install -y tomcat-native apr fontconfig "$ADOPTOPENJDK_VERSION"
    ;;

  _ubuntu)
    # ubuntu stuff here
    export DEBIAN_FRONTEND=noninteractive
    sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get update
    sudo apt-get install -y libtcnative-1 libapr1 wget apt-transport-https gpg
    TOMCAT_LIB_PATH="/usr/lib/x86_64-linux-gnu"
    # Add adoptium repo
    DEB_JDK_REPO="https://packages.adoptium.net/artifactory/deb/"
    if ! grep -qs "$DEB_JDK_REPO" "/etc/apt/sources.list" "/etc/apt/sources.list.d/"*; then
      wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg >/dev/null
      chmod 644 /etc/apt/trusted.gpg.d/adoptium.gpg
      echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
    fi
    sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get update
    sudo apt-get install -y "$ADOPTOPENJDK_VERSION"
    sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade
    ;;

  _*)
    echo "can't install adoptium on unrecognized platform: \"$(platform)\""
    ;;
  esac

}

function step_download() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  local ret=0

  # download labkey distribution
  cd "$LABKEY_SRC_HOME" || exit
  if [ ! -s "${LABKEY_APP_HOME}/src/labkey/${LABKEY_DIST_FILENAME}" ]; then
    wget -N "$LABKEY_DIST_URL"
  fi

  if [ -s "${LABKEY_APP_HOME}/src/labkey/${LABKEY_DIST_FILENAME}" ]; then
    tar -xzf "$LABKEY_DIST_FILENAME"
  else
    # fail if download fails or dist file is 0 bytes
    console_msg "ERROR: LabKey distribution file: ${LABKEY_APP_HOME}/src/labkey/${LABKEY_DIST_FILENAME} failed to download correctly! Exiting..."
    export ret=1
  fi

  return "$ret"

}

function step_create_app_properties() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if [[ $TOMCAT_INSTALL_TYPE == "Standard" ]]; then
    console_msg "Skipping creating of application.properties as this file is not needed for non-embedded tomcat installs"
    return 0
  fi

  # application properties depends on the ${LABKEY_INSTALL_HOME} directory - error if no directory exists
  if [ ! -d "${LABKEY_INSTALL_HOME}" ]; then
    console_msg "ERROR! - The ${LABKEY_INSTALL_HOME} does not exist - I gotta put this file somewhere!"
  else
    NewFile="${LABKEY_INSTALL_HOME}/application.properties"
    (
      /bin/cat <<-APP_PROPS_HERE

						server.port=${LABKEY_HTTPS_PORT}

						server.ssl.enabled=true
						server.ssl.enabled-protocols=${TOMCAT_SSL_ENABLED_PROTOCOLS}
						server.ssl.protocol=${TOMCAT_SSL_PROTOCOL}
						server.ssl.key-alias=${TOMCAT_KEYSTORE_ALIAS}
						server.ssl.key-store=${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}
						server.ssl.key-store-password=${TOMCAT_KEYSTORE_PASSWORD}
						server.ssl.key-store-type=${TOMCAT_KEYSTORE_FORMAT}
						server.ssl.ciphers=${TOMCAT_SSL_CIPHERS}

						# HTTP-only port for servers that need to handle both HTTPS (configure via server.port and server.ssl above) and HTTP
						#context.httpPort=8080

						# Database connections. All deployments need a labkeyDataSource as their primary database. Add additional external
						# data sources by specifying the required properties (at least driverClassName, url, username, and password)
						# with a prefix of context.resources.jdbc.<dataSourceName>.
						context.resources.jdbc.labkeyDataSource.type=javax.sql.DataSource
						context.resources.jdbc.labkeyDataSource.driverClassName=org.postgresql.Driver
						context.resources.jdbc.labkeyDataSource.url=jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}${POSTGRES_PARAMETERS}
						context.resources.jdbc.labkeyDataSource.username=${POSTGRES_USER}
						context.resources.jdbc.labkeyDataSource.password=${POSTGRES_PASSWORD}
						context.resources.jdbc.labkeyDataSource.maxTotal=50
						context.resources.jdbc.labkeyDataSource.maxIdle=10
						context.resources.jdbc.labkeyDataSource.maxWaitMillis=120000
						context.resources.jdbc.labkeyDataSource.accessToUnderlyingConnectionAllowed=true
						context.resources.jdbc.labkeyDataSource.validationQuery=SELECT 1
						#context.resources.jdbc.labkeyDataSource.logQueries=true
						#context.resources.jdbc.labkeyDataSource.displayName=Alternate Display Name

						#context.resources.jdbc.@@extraJdbcDataSource@@.driverClassName=@@extraJdbcDriverClassName@@
						#context.resources.jdbc.@@extraJdbcDataSource@@.url=@@extraJdbcUrl@@
						#context.resources.jdbc.@@extraJdbcDataSource@@.username=@@extraJdbcUsername@@
						#context.resources.jdbc.@@extraJdbcDataSource@@.password=@@extraJdbcPassword@@

						#useLocalBuild#context.webAppLocation=@@pathToServer@@/build/deploy/labkeyWebapp
						context.EncryptionKey=${LABKEY_MEK}

						# By default, we deploy to the root context path. However, some servers have historically used /labkey or even /cpas
						#context.contextPath=/labkey

						# Using a legacy context path provides backwards compatibility with old deployments. A typical use case would be to
						# deploy to the root context (the default) and configure /labkey as the legacy path. GETs will be redirected.
						# All other methods (POSTs, PUTs, etc) will be handled server-side via a servlet forward.
						#context.legacyContextPath=/labkey

						# Other webapps to be deployed, most commonly to deliver a set of static files. The context path to deploy into is the
						# property name after the "context.additionalWebapps." prefix, and the value is the location of the webapp on disk
						#context.additionalWebapps.firstContextPath=/my/webapp/path
						#context.additionalWebapps.secondContextPath=/my/other/webapp/path

						#context.oldEncryptionKey=
						#context.requiredModules=
						#context.pipelineConfig=/path/to/pipeline/config/dir
						context.serverGUID=${LABKEY_GUID}
						#context.bypass2FA=true
						#context.workDirLocation=/path/to/desired/workDir

						mail.smtpHost=${SMTP_HOST}
						mail.smtpPort=${SMTP_PORT}
						mail.smtpUser=${SMTP_USER}
						mail.smtpFrom=${SMTP_FROM}
						mail.smtpPassword=${SMTP_PASSWORD}
						mail.smtpStartTlsEnable=${SMTP_STARTTLS}
						#mail.smtpSocketFactoryClass=@@smtpSocketFactoryClass@@
						mail.smtpAuth=${SMTP_AUTH}

						# Optional - JMS configuration for remote ActiveMQ message management for distributed pipeline jobs
						# https://www.labkey.org/Documentation/wiki-page.view?name=jmsQueue
						#context.resources.jms.ConnectionFactory.type=org.apache.activemq.ActiveMQConnectionFactory
						#context.resources.jms.ConnectionFactory.factory=org.apache.activemq.jndi.JNDIReferenceFactory
						#context.resources.jms.ConnectionFactory.description=JMS Connection Factory
						# Use an in-process ActiveMQ queue
						#context.resources.jms.ConnectionFactory.brokerURL=vm://localhost?broker.persistent=false&broker.useJmx=false
						# Use an out-of-process ActiveMQ queue
						#context.resources.jms.ConnectionFactory.brokerURL=tcp://localhost:61616
						#context.resources.jms.ConnectionFactory.brokerName=LocalActiveMQBroker

						# Optional - LDAP configuration for LDAP group/user synchronization
						# https://www.labkey.org/Documentation/wiki-page.view?name=LDAP_sync
						#context.resources.ldap.ConfigFactory.type=org.labkey.premium.ldap.LdapConnectionConfigFactory
						#context.resources.ldap.ConfigFactory.factory=org.labkey.premium.ldap.LdapConnectionConfigFactory
						#context.resources.ldap.ConfigFactory.host=myldap.mydomain.com
						#context.resources.ldap.ConfigFactory.port=389
						#context.resources.ldap.ConfigFactory.principal=cn=read_user
						#context.resources.ldap.ConfigFactory.credentials=read_user_password
						#context.resources.ldap.ConfigFactory.useTls=false
						#context.resources.ldap.ConfigFactory.useSsl=false
						#context.resources.ldap.ConfigFactory.sslProtocol=SSLv3

						#useLocalBuild#spring.devtools.restart.additional-paths=@@pathToServer@@/build/deploy/modules,@@pathToServer@@/build/deploy/embedded/config

						# HTTP session timeout for users - defaults to 30 minutes
						#server.servlet.session.timeout=30m


						#Enable shutdown endpoint
						management.endpoint.shutdown.enabled=false
						# turn off other endpoints
						management.endpoints.enabled-by-default=false
						# allow access via http
						management.endpoints.web.exposure.include=*
						# Use a separate port for management endpoints. Required if LabKey is using default (ROOT) context path
						#management.server.port=@@shutdownPort@@

						management.endpoint.env.keys-to-sanitize=.*user.*,.*pass.*,secret,key,token,.*credentials.*,vcap_services,sun.java.command,.*key-store.*

						# Don't show the Spring banner on startup
						spring.main.banner-mode=off
						#logging.config=path/to/alternative/log4j2.xml

						# Optional - JMS configuration for remote ActiveMQ message management for distributed pipeline jobs
						# https://www.labkey.org/Documentation/wiki-page.view?name=jmsQueue
						#context.resources.jms.name=jms/ConnectionFactory
						#context.resources.jms.type=org.apache.activemq.ActiveMQConnectionFactory
						#context.resources.jms.factory=org.apache.activemq.jndi.JNDIReferenceFactory
						#context.resources.jms.description=JMS Connection Factory
						#context.resources.jms.brokerURL=vm://localhost?broker.persistent=false&broker.useJmx=false
						#context.resources.jms.brokerName=LocalActiveMQBroker

						# Turn on JSON-formatted HTTP access logging to stdout. See issue 48565
						# https://tomcat.apache.org/tomcat-9.0-doc/config/valve.html#JSON_Access_Log_Valve
						#jsonaccesslog.enabled=true

						# Optional configuration, modeled on the non-JSON Spring Boot properties
						# https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html#application-properties.server.server.tomcat.accesslog.buffered
						#jsonaccesslog.pattern=%h %t %m %U %s %b %D %S "%{Referer}i" "%{User-Agent}i" %{LABKEY.username}s
						#jsonaccesslog.condition-if=attributeName
						#jsonaccesslog.condition-unless=attributeName

						# Define one or both of 'csp.report' and 'csp.enforce' to enable Content Security Policy (CSP) headers
						# Do not copy-and-paste these examples for any production environment without understanding the meaning of each directive!

						# example usage 1 - very strict, disallows 'external' websites, disallows unsafe-inline, but only reports violations (does not enforce)

						#csp.report=\\
						#    default-src 'self';\\
						#    connect-src 'self' \${LABKEY.ALLOWED.CONNECTIONS} ;\\
						#    object-src 'none' ;\\
						#    style-src 'self' 'unsafe-inline' ;\\
						#    img-src 'self' data: ;\\
						#    font-src 'self' data: ;\\
						#    script-src 'unsafe-eval' 'strict-dynamic' 'nonce-\${REQUEST.SCRIPT.NONCE}';\\
						#    base-uri 'self' ;\\
						#    upgrade-insecure-requests ;\\
						#    frame-ancestors 'self' ;\\
						#    report-uri https://www.labkey.org/admin-contentsecuritypolicyreport.api?\${CSP.REPORT.PARAMS} ;

						# example usage 2 - less strict but enforces directives, (NOTE: unsafe-inline is still required for many modules)

						#csp.enforce=\\
						#    default-src 'self' https: ;\\
						#    connect-src 'self' https: \${LABKEY.ALLOWED.CONNECTIONS};\\
						#    object-src 'none' ;\\
						#    style-src 'self' https: 'unsafe-inline' ;\\
						#    img-src 'self' data: ;\\
						#    font-src 'self' data: ;\\
						#    script-src 'unsafe-inline' 'unsafe-eval' 'strict-dynamic' 'nonce-\${REQUEST.SCRIPT.NONCE}';\\
						#    base-uri 'self' ;\\
						#    upgrade-insecure-requests ;\\
						#    frame-ancestors 'self' ;\\
						#    report-uri  https://www.labkey.org/admin-contentsecuritypolicyreport.api?\${CSP.REPORT.PARAMS} ;

						# Use a non-temp directory for tomcat
						server.tomcat.basedir=${TOMCAT_INSTALL_HOME}

						# Enable tomcat access log
						server.tomcat.accesslog.enabled=true
						server.tomcat.accesslog.directory=${LABKEY_INSTALL_HOME}/logs
						server.tomcat.accesslog.pattern=%h %l %u %t "%r" %s %b %D %S %I "%{Referrer}i" "%{User-Agent}i" %{LABKEY.username}s



			APP_PROPS_HERE
    ) >"$NewFile"
  fi
}

function step_startup_properties() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if [ ! -d "$LABKEY_INSTALL_HOME" ]; then
    console_msg "ERROR: LabKey Install Home directory does not exist!"
    return 1
  fi

  if [ -d "$LABKEY_INSTALL_HOME" ]; then
    if [ ! -d "$LABKEY_STARTUP_DIR" ]; then
      create_req_dir "LABKEY_STARTUP_DIR"
    fi
    # create startup properties file
    NewFile="$LABKEY_STARTUP_DIR/50_basic-startup.properties"
    (
      /bin/cat <<-STARTUP_PROPS_HERE
				LookAndFeelSettings.companyName=${LABKEY_COMPANY_NAME}
				#LookAndFeelSettings.reportAProblemPath=https://www.labkey.org/hosted-support.url
				LookAndFeelSettings.systemDescription=${LABKEY_SYSTEM_DESCRIPTION}
				LookAndFeelSettings.systemEmailAddress=${LABKEY_SYSTEM_EMAIL_ADDRESS}
				LookAndFeelSettings.systemShortName=${LABKEY_SYSTEM_SHORT_NAME}
				SiteRootSettings.siteRootFile=${LABKEY_FILES_ROOT}
				SiteSettings.baseServerURL=${LABKEY_BASE_SERVER_URL}
				SiteSettings.defaultDomain=${LABKEY_DEFAULT_DOMAIN}
				SiteSettings.pipelineToolsDirectory=${LABKEY_INSTALL_HOME}
				SiteSettings.sslPort=${LABKEY_HTTPS_PORT}
				SiteSettings.sslRequired=true

				STARTUP_PROPS_HERE
    ) >"$NewFile"
  fi
}

function step_postgres_configure() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  case "_$(platform)" in
  _amzn)
    # Install the Postgresql repository RPM
    # note this method is required for AMZN linux and supports PG versions 12-15 - v16 not supported by PG repo
    if [[ -z $POSTGRES_VERSION ]]; then
      DEFAULT_POSTGRES_VERSION="15"
    else
      DEFAULT_POSTGRES_VERSION=$POSTGRES_VERSION
    fi

    if [ ! -f "/etc/yum.repos.d/pgdg.repo" ]; then
      NewPGRepoFile="/etc/yum.repos.d/pgdg.repo"
      (
        /bin/cat <<-PG_REPO_HERE
				[pgdg$DEFAULT_POSTGRES_VERSION]
				name=PostgreSQL $DEFAULT_POSTGRES_VERSION for RHEL/CentOS 7 - x86_64
				baseurl=https://download.postgresql.org/pub/repos/yum/$DEFAULT_POSTGRES_VERSION/redhat/rhel-7-x86_64
				enabled=1
				gpgcheck=0

				PG_REPO_HERE
      ) >"$NewPGRepoFile"
    fi

    if [ "$POSTGRES_SVR_LOCAL" == "TRUE" ]; then
      sudo yum clean metadata
      sudo yum update -y
      sudo yum install "postgresql$DEFAULT_POSTGRES_VERSION-server" -y
      # TODO: These are pre-reqs for Amazon Linux - Move to the pre-reqs function
      sudo yum install tomcat-native.x86_64 apr fontconfig -y

      if [ ! -f "/var/lib/pgsql/data/$DEFAULT_POSTGRES_VERSION" ]; then
        "/usr/pgsql-$DEFAULT_POSTGRES_VERSION/bin/postgresql-$DEFAULT_POSTGRES_VERSION-setup" initdb "postgresql-$DEFAULT_POSTGRES_VERSION"
      fi
      sudo systemctl enable "postgresql-$DEFAULT_POSTGRES_VERSION"
      sudo systemctl start "postgresql-$DEFAULT_POSTGRES_VERSION"
      sudo -u postgres psql -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
      sudo -u postgres psql -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
      sudo -u postgres psql -c "revoke all on database $POSTGRES_DB from public;"
      sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' "/var/lib/pgsql/$DEFAULT_POSTGRES_VERSION/data/pg_hba.conf"
      sudo systemctl restart "postgresql-$DEFAULT_POSTGRES_VERSION"
      console_msg "Postgres Server and Client Installed ..."
    else
      sudo yum clean metadata
      sudo yum install "postgresql-client-$DEFAULT_POSTGRES_VERSION" -y
      # TODO: These are pre-reqs for Amazon Linux - Move to the pre-reqs function
      sudo yum install tomcat-native.x86_64 apr fontconfig -y
      console_msg "Postgres Client Installed ..."
    fi
    ;;

  _almalinux)
    if [ ! -e "/etc/yum.repos.d/pgdg-redhat-all.repo" ]; then
      sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
      sudo dnf -qy module disable postgresql
      sudo dnf clean metadata
      sudo dnf update -y
    fi

    if [[ -z $POSTGRES_VERSION ]]; then
      DEFAULT_POSTGRES_VERSION="15"
    else
      DEFAULT_POSTGRES_VERSION=$POSTGRES_VERSION
    fi

    if [ "$POSTGRES_SVR_LOCAL" == "TRUE" ]; then
      sudo dnf install "postgresql$DEFAULT_POSTGRES_VERSION-server" -y

      if [ ! -f "/var/lib/pgsql/data/$DEFAULT_POSTGRES_VERSION" ]; then
        "/usr/pgsql-$DEFAULT_POSTGRES_VERSION/bin/postgresql-$DEFAULT_POSTGRES_VERSION-setup" initdb "postgresql-$DEFAULT_POSTGRES_VERSION"
      fi
      sudo systemctl enable "postgresql-$DEFAULT_POSTGRES_VERSION"
      sudo systemctl start "postgresql-$DEFAULT_POSTGRES_VERSION"
      sudo -u postgres psql -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
      sudo -u postgres psql -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
      sudo -u postgres psql -c "revoke all on database $POSTGRES_DB from public;"
      sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' "/var/lib/pgsql/$DEFAULT_POSTGRES_VERSION/data/pg_hba.conf"
      sudo systemctl restart "postgresql-$DEFAULT_POSTGRES_VERSION"
      console_msg "Postgres Server and Client Installed ..."
    else
      sudo dnf clean metadata
      sudo dnf install "postgresql$DEFAULT_POSTGRES_VERSION" -y
      console_msg "Postgres Client Installed ..."
    fi
    ;;

  _rhel)
    if [ ! -e "/etc/yum.repos.d/pgdg-redhat-all.repo" ]; then
      sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
      sudo dnf -qy module disable postgresql
      sudo dnf clean metadata
      sudo dnf update -y
    fi

    if [[ -z $POSTGRES_VERSION ]]; then
      DEFAULT_POSTGRES_VERSION="15"
    else
      DEFAULT_POSTGRES_VERSION=$POSTGRES_VERSION
    fi

    if [ "$POSTGRES_SVR_LOCAL" == "TRUE" ]; then
      sudo dnf install "postgresql$DEFAULT_POSTGRES_VERSION-server" -y

      if [ ! -f "/var/lib/pgsql/data/$DEFAULT_POSTGRES_VERSION" ]; then
        "/usr/pgsql-$DEFAULT_POSTGRES_VERSION/bin/postgresql-$DEFAULT_POSTGRES_VERSION-setup" initdb "postgresql-$DEFAULT_POSTGRES_VERSION"
      fi
      sudo systemctl enable "postgresql-$DEFAULT_POSTGRES_VERSION"
      sudo systemctl start "postgresql-$DEFAULT_POSTGRES_VERSION"
      sudo -u postgres psql -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
      sudo -u postgres psql -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
      sudo -u postgres psql -c "revoke all on database $POSTGRES_DB from public;"
      sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' "/var/lib/pgsql/$DEFAULT_POSTGRES_VERSION/data/pg_hba.conf"
      sudo systemctl restart "postgresql-$DEFAULT_POSTGRES_VERSION"
      console_msg "Postgres Server and Client Installed ..."
    else
      sudo dnf clean metadata
      sudo dnf install "postgresql$DEFAULT_POSTGRES_VERSION" -y
      console_msg "Postgres Client Installed ..."
    fi
    ;;

  _ubuntu)
    sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get update
    # Postgresql 12 included in Ubuntu 20.04 APT repo - otherwise install from Postgresql repos
    if [ "$POSTGRES_SVR_LOCAL" == "TRUE" ]; then
      if [ "$(platform_version)" == "20.04" ]; then
        if [[ -n $POSTGRES_VERSION && $POSTGRES_VERSION != "12" ]]; then
          sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
          wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get update
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install "postgresql-$POSTGRES_VERSION"
        else
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install postgresql-12
        fi
      fi
      # Postgresql 14 included in Ubuntu 22.04 APT repo - otherwise install from Postgresql repos
      if [ "$(platform_version)" == "22.04" ]; then
        if [[ -n $POSTGRES_VERSION && $POSTGRES_VERSION != "14" ]]; then
          sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
          wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get update
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install "postgresql-$POSTGRES_VERSION"
        else
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install postgresql-14
        fi
      fi

      sudo systemctl enable postgresql
      sudo systemctl start postgresql
      sudo -u postgres psql -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
      sudo -u postgres psql -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
      sudo -u postgres psql -c "revoke all on database $POSTGRES_DB from public;"
      sudo systemctl restart postgresql
      console_msg "Postgres Server and Client Installed ..."
    else
      if [ "$(platform_version)" == "20.04" ]; then
        if [[ -n $POSTGRES_VERSION && $POSTGRES_VERSION != "12" ]]; then
          sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
          wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get update
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install "postgresql-client-$POSTGRES_VERSION"
        else
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install postgresql-client-12
        fi
      fi
      if [ "$(platform_version)" == "22.04" ]; then
        if [[ -n $POSTGRES_VERSION && $POSTGRES_VERSION != "14" ]]; then
          sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
          wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get update
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install "postgresql-client-$POSTGRES_VERSION"
        else
          sudo DEBIAN_PRIORITY=critical DEBIAN_FRONTEND=noninteractive apt-get -y install postgresql-client-14
        fi
      fi
      console_msg "Postgres Client Installed ..."
    fi

    ;;

  _*)
    echo "can't install postgres on unrecognized platform: \"$(platform)\""
    ;;
  esac

}

function step_remote_db_provision() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if [ "$POSTGRES_SVR_LOCAL" == "FALSE" ] && [ "$POSTGRES_PROVISION_REMOTE_DB" == "TRUE" ]; then
    if [[ -n $POSTGRES_REMOTE_ADMIN_PASSWORD ]]; then
      export PGPASSWORD=$POSTGRES_REMOTE_ADMIN_PASSWORD
    else
      console_msg "You must supply a remote postgres_admin password to provision the remote database."
      return 1
    fi
    console_msg "Provisioning remote postgres database ..."
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_REMOTE_ADMIN_USER" -d postgres -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_REMOTE_ADMIN_USER" -d postgres -c "grant $POSTGRES_USER to $POSTGRES_REMOTE_ADMIN_USER;"
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_REMOTE_ADMIN_USER" -d postgres -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_REMOTE_ADMIN_USER" -d postgres -c "revoke all on database $POSTGRES_DB from public;"
    console_msg "Finished provisioning remote postgres database"
  fi

}

function step_tomcat_user() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # Add Tomcat user
  if ! id "$TOMCAT_USERNAME" &>/dev/null; then
    # add tomcat user
    sudo useradd -r -M -u "$TOMCAT_UID" -U -s '/bin/false' "$TOMCAT_USERNAME"
    console_msg "a tomcat service account user has been added as $TOMCAT_USERNAME  with UID: $TOMCAT_UID"
  fi

}

function step_tomcat_cert() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_INSTALL_HOME/SSL"

  # generate self-signed cert
  if [ ! -f "${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}" ]; then

    keytool \
      -genkeypair \
      -dname "CN=${CERT_CN},OU=${CERT_OU},O=${CERT_O},L=${CERT_L},S=${CERT_ST},C=${CERT_C}" \
      -alias "$TOMCAT_KEYSTORE_ALIAS" \
      -keyalg RSA \
      -keysize 4096 \
      -validity 720 \
      -keystore "${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}" \
      -storepass "$TOMCAT_KEYSTORE_PASSWORD" \
      -keypass "$TOMCAT_KEYSTORE_PASSWORD" \
      -ext SAN=dns:localhost,ip:127.0.0.1

    keytool \
      -exportcert \
      -alias "$TOMCAT_KEYSTORE_ALIAS" \
      -file "${TOMCAT_KEYSTORE_BASE_PATH}/tomcat.cer" \
      -keystore "${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}" \
      -storepass "$TOMCAT_KEYSTORE_PASSWORD"

    chown "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}"
    chmod 440 "${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}"

    console_msg "A Self signed SSL certificate has been created and stored in the keystoreFile at ${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}"
  fi

}

function step_configure_labkey() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  local ret=0

  # configure labkey to run
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${LABKEY_APP_HOME}/"
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${LABKEY_SRC_HOME}/"
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${LABKEY_INSTALL_HOME}/"
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${TOMCAT_INSTALL_HOME}/"

  # Configure for embedded
  if [[ $TOMCAT_INSTALL_TYPE == "Embedded" ]]; then

    # TODO not sure if this is needed
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "/work/Tomcat/"

    # strip -embedded from filename to get expected directory name

    if [ -d "${LABKEY_APP_HOME}/src/labkey/${LABKEY_DIST_DIR}" ]; then
      # copy jar file to LABKEY_INSTALL_HOME for tomcat_lk.service
      if [ -f "${LABKEY_SRC_HOME}/${LABKEY_DIST_DIR}/labkeyServer-${LABKEY_VERSION}.jar" ]; then
        cp -a "${LABKEY_SRC_HOME}/${LABKEY_DIST_DIR}/labkeyServer-${LABKEY_VERSION}.jar" "${LABKEY_INSTALL_HOME}/labkeyServer.jar"
        cp -a "${LABKEY_SRC_HOME}/${LABKEY_DIST_DIR}/VERSION" "${LABKEY_INSTALL_HOME}/VERSION"
      elif [ -f "${LABKEY_SRC_HOME}/${LABKEY_DIST_DIR}/labkeyServer.jar" ]; then
        cp -a "${LABKEY_SRC_HOME}/${LABKEY_DIST_DIR}/labkeyServer.jar" "${LABKEY_INSTALL_HOME}/labkeyServer.jar"
        cp -a "${LABKEY_SRC_HOME}/${LABKEY_DIST_DIR}/VERSION" "${LABKEY_INSTALL_HOME}/VERSION"
      else
        console_msg "ERROR: Something is wrong. Unable copy ${LABKEY_INSTALL_HOME}/labkeyServer.jar, please verify LabKey Version and distribution."
        export ret=1
      fi
      # copy bin directory from distribution
      if [ -d "${LABKEY_APP_HOME}/src/labkey/${LABKEY_DIST_DIR}/bin/" ]; then
        cp -a "${LABKEY_APP_HOME}/src/labkey/${LABKEY_DIST_DIR}/bin/" "${LABKEY_INSTALL_HOME}/bin/"
      fi
    else
      console_msg "ERROR: Something is wrong. Unable to configure LabKey, please verify paths to LabKey Jar or LabKey VERSION and DISTRIBUTION Vars."
      console_msg "Trying to find ${LABKEY_SRC_HOME}/${LABKEY_DIST_DIR}/labkeyServer-${LABKEY_VERSION}.jar"
    fi
  fi

  if [[ $TOMCAT_INSTALL_TYPE == "Standard" ]]; then
    # install non-embedded LabKey distro
    cd "$LABKEY_SRC_HOME" || exit
    $LABKEY_INSTALLER_CMD
  fi

  return "$ret"

}

function step_tomcat_service_embedded() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if [[ $TOMCAT_INSTALL_TYPE != "Embedded" ]]; then
    console_msg "Skipping configuring tomcat service for embedded - this is not an embedded install."
    console_msg "Consider skipping this step in future runs by using the Env var LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_EMBEDDED_STEP=1"
    return 0
  fi

  # Env Vars for tomcat_service file
  # shellcheck disable=SC2046
  JAVA_HOME="$(dirname $(dirname $(readlink -f /etc/alternatives/java)))"
  JAVA_PRE_JAR_OPS="-Duser.timezone=${TOMCAT_TIMEZONE} -Djava.library.path=${TOMCAT_LIB_PATH} -Djava.awt.headless=true -Xms$JAVA_HEAP_SIZE -Xmx$JAVA_HEAP_SIZE -Djava.security.egd=file:/dev/./urandom"
  JAVA_MID_JAR_OPS="-XX:+HeapDumpOnOutOfMemoryError -XX:+UseContainerSupport -XX:HeapDumpPath=${TOMCAT_TMP_DIR} -Djava.net.preferIPv4Stack=true"
  LABKEY_JAR_OPS="-Dlabkey.home=${LABKEY_INSTALL_HOME} -Dlabkey.log.home=${LABKEY_INSTALL_HOME}/logs -Dlabkey.externalModulesDir=${LABKEY_INSTALL_HOME}/externalModules -Djava.io.tmpdir=${TOMCAT_TMP_DIR}"
  JAVA_FLAGS_JAR_OPS="-Dorg.apache.catalina.startup.EXIT_ON_INIT_FAILURE=true -DsynchronousStartup=true -DterminateOnStartupFailure=true"
  JAVA_LOG_JAR_OPS="-XX:ErrorFile=${LABKEY_INSTALL_HOME}/logs/error_%p.log -Dlog4j.configurationFile=log4j2.xml"

  # Add Tomcat service
  if [ ! -f "/etc/systemd/system/tomcat_lk.service" ]; then

    NewFile='/etc/systemd/system/tomcat_lk.service'
    (
      /bin/cat <<-HERE_TOMCAT_SERVICE
				# Systemd unit file for tomcat_lk

				[Unit]
				Description=lk Apache Tomcat Application
				After=syslog.target network.target

				[Service]
				Type=simple
				Environment="CATALINA_HOME=${TOMCAT_INSTALL_HOME}"
				Environment="JAVA_HOME=${JAVA_HOME}"
				Environment="JAVA_PRE_JAR_OPS=${JAVA_PRE_JAR_OPS}"
				Environment="JAVA_MID_JAR_OPS=${JAVA_MID_JAR_OPS}"
				Environment="LABKEY_JAR_OPS=${LABKEY_JAR_OPS}"
				Environment="JAVA_LOG_JAR_OPS=${JAVA_LOG_JAR_OPS}"
				Environment="JAVA_FLAGS_JAR_OPS=${JAVA_FLAGS_JAR_OPS}"
				WorkingDirectory=${LABKEY_INSTALL_HOME}
				OOMScoreAdjust=-500

				ExecStart=$JAVA_HOME/bin/java \$JAVA_PRE_JAR_OPS \$JAVA_MID_JAR_OPS \$LABKEY_JAR_OPS \$JAVA_LOG_JAR_OPS \$JAVA_FLAGS_JAR_OPS -jar ${LABKEY_INSTALL_HOME}/labkeyServer.jar
				SuccessExitStatus=0 143
				Restart=on-failure
				RestartSec=15

				User=$TOMCAT_USERNAME
				Group=$TOMCAT_USERNAME

				[Install]
				WantedBy=multi-user.target
				HERE_TOMCAT_SERVICE
    ) >$NewFile
  fi

}
# shellcheck disable=SC2120
function step_tomcat_service_standard() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  if [[ $TOMCAT_INSTALL_TYPE != "Standard" ]]; then
    console_msg "Skipping tomcat (standard) service config."
    console_msg "Consider skipping this step in future runs by using the Env var LABKEY_INSTALL_SKIP_TOMCAT_SERVICE_STANDARD_STEP=1"
    return 0
  fi

  if [[ $TOMCAT_INSTALL_TYPE == "Standard" ]]; then
    # shellcheck disable=SC2046
    JAVA_HOME="$(dirname $(dirname $(readlink -f /etc/alternatives/java)))"
    create_req_dir "$TOMCAT_INSTALL_HOME/conf/Catalina/localhost"

    # Download tomcat
    cd "${LABKEY_APP_HOME}/src/" || exit
    wget --no-verbose "$TOMCAT_URL"
    tar xzf "apache-tomcat-$TOMCAT_VERSION.tar.gz"
    cp -aR "${LABKEY_APP_HOME}"/src/apache-tomcat-"$TOMCAT_VERSION"/* "$TOMCAT_INSTALL_HOME/"
    chmod 0755 "$TOMCAT_INSTALL_HOME"
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_INSTALL_HOME/"
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_TMP_DIR/"
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$LABKEY_INSTALL_HOME/"
    rm "${LABKEY_APP_HOME}/src/apache-tomcat-$TOMCAT_VERSION.tar.gz"
    rm -Rf "${LABKEY_APP_HOME}/src/apache-tomcat-$TOMCAT_VERSION"
    chmod 0700 "${CATALINA_HOME}/conf/Catalina/localhost"
    # remove default tomcat applications
    if [[ -d "$TOMCAT_INSTALL_HOME/webapps/docs/" ]]; then
      rm -Rf "$TOMCAT_INSTALL_HOME/webapps/docs/"
    fi
    if [[ -d "$TOMCAT_INSTALL_HOME/webapps/examples/" ]]; then
      rm -Rf "$TOMCAT_INSTALL_HOME/webapps/examples/"
    fi
    if [[ -d "$TOMCAT_INSTALL_HOME/webapps/host-manager/" ]]; then
      rm -Rf "$TOMCAT_INSTALL_HOME/webapps/host-manager/"
    fi
    if [[ -d "$TOMCAT_INSTALL_HOME/webapps/manager/" ]]; then
      rm -Rf "$TOMCAT_INSTALL_HOME/webapps/manager/"
    fi
    if [[ $TOMCAT_CONTEXT_PATH == "ROOT" ]]; then
      if [[ -d "$TOMCAT_INSTALL_HOME/webapps/ROOT/" ]]; then
        rm -Rf "$TOMCAT_INSTALL_HOME/webapps/ROOT/"
      fi
    fi
    if [[ $TOMCAT_CONTEXT_PATH != "ROOT" ]]; then
      if [[ -d "$TOMCAT_INSTALL_HOME/webapps/ROOT/" ]]; then
        rm -Rf "$TOMCAT_INSTALL_HOME/webapps/ROOT/"
        mkdir -p "$TOMCAT_INSTALL_HOME/webapps/ROOT/"
        echo "<% response.sendRedirect(\"/$TOMCAT_CONTEXT_PATH\"); %>" >"$TOMCAT_INSTALL_HOME/webapps/ROOT/index.jsp"
        chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_INSTALL_HOME/webapps/ROOT/"
      fi
    fi

    # Create Labkey Service script - prevents unexpected shutdown of LabKey service during upgrades etc.
    NewScript="$TOMCAT_INSTALL_HOME/bin/labkey_service.sh"
    (
      /bin/cat <<-HERE_LABKEY_SERVICE_SCRIPT
		#!/usr/bin/env bash

		OPERATION="\$1"

		if [[ "\$OPERATION" == 'stop' ]]; then
			# wait for labkey upgrade to complete before stopping tomcat
			LOCKFILE="$LABKEY_INSTALL_HOME/labkeyUpgradeLockFile"

			while [ -f "\$LOCKFILE" ]; do
				sleep 3
			done

		fi

		"$TOMCAT_INSTALL_HOME/bin/catalina.sh" \$@

		HERE_LABKEY_SERVICE_SCRIPT
    ) >"$NewScript"
    chmod 755 "$NewScript"

    # Create Standard Tomcat Systemd service file -

    #create tomcat_lk systemd service file
    NewFile='/etc/systemd/system/tomcat_lk.service'
    (
      /bin/cat <<-HERE_STD_TOMCAT_SERVICE
				# Systemd unit file for tomcat_lk

				[Unit]
				Description=lk Apache Tomcat Application
				After=syslog.target network.target

				[Service]
				Type=forking
				Environment="JAVA_HOME=$JAVA_HOME"
				Environment="CATALINA_BASE=$TOMCAT_INSTALL_HOME"
				Environment="CATALINA_HOME=$TOMCAT_INSTALL_HOME"
				Environment="CATALINA_OPTS=-Djava.library.path=$TOMCAT_LIB_PATH -Djava.awt.headless=true -Duser.timezone=$TOMCAT_TIMEZONE -Xms$JAVA_HEAP_SIZE -Xmx$JAVA_HEAP_SIZE -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$TOMCAT_TMP_DIR -Djava.net.preferIPv4Stack=true -Dlog4j2.formatMsgNoLookups=true"
				Environment="CATALINA_TMPDIR=$TOMCAT_TMP_DIR"
				OOMScoreAdjust=-500


				ExecStart=$TOMCAT_INSTALL_HOME/bin/labkey_service.sh start
				ExecStop=$TOMCAT_INSTALL_HOME/bin/labkey_service.sh stop
				SuccessExitStatus=0 143
				Restart=on-failure
				RestartSec=2

				User=$TOMCAT_USERNAME
				Group=$TOMCAT_USERNAME

				[Install]
				WantedBy=multi-user.target
				HERE_STD_TOMCAT_SERVICE
    ) >$NewFile

    # Set Systemd property AmbientCapabilities=CAP_NET_BIND_SERVICE to allow tomcat to bind to ports <1024
    if [[ -f "/etc/systemd/system/tomcat_lk.service" && $TOMCAT_USE_PRIVILEGED_PORTS == "TRUE" ]]; then
      console_msg "Configuring tomcat_lk.service for privileged ports..."
      if ! grep -iq 'AmbientCapabilities' "/etc/systemd/system/tomcat_lk.service"; then
        sed -i '/\[Service\]/a AmbientCapabilities=CAP_NET_BIND_SERVICE' /etc/systemd/system/tomcat_lk.service
      fi
    fi

    # create tomcat server.xml
    TomcatServerFile="$CATALINA_HOME/conf/server.xml"
    (
      /bin/cat <<SERVERXMLHERE
<?xml version='1.0' encoding='utf-8' ?>
<!--
    Licensed to the Apache Software Foundation (ASF) under one or more
    contributor license agreements. See the NOTICE file distributed with
    this work for additional information regarding copyright ownership.
    The ASF licenses this file to You under the Apache License, Version 2.0
    (the "License"); you may not use this file except in compliance with
    the License. You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
-->

<!--
    Note: A "Server" is not itself a "Container", so you may not define
    subcomponents such as "Valves" at this level.
    Documentation at /docs/config/server.html
-->
<Server port="8005" shutdown="SHUTDOWN">

    <!--
        APR library loader.
        Documentation at /docs/apr.html
    -->
    <Listener
        className="org.apache.catalina.core.AprLifecycleListener"
        SSLEngine="on"
        useAprConnector="true"
    />

    <Listener className="org.apache.catalina.startup.VersionLoggerListener" />

    <!--
        Security listener.
        Documentation at /docs/config/listeners.html
    -->
    <Listener className="org.apache.catalina.security.SecurityListener" />

    <!--
        Prevent memory leaks due to use of particular java/javax APIs
    -->
    <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
    <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
    <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

    <!--
        Global JNDI resources
        Documentation at /docs/jndi-resources-howto.html
    -->
    <GlobalNamingResources>

        <!--
            Editable user database that can also be used by UserDatabaseRealm
            to authenticate users
        -->
        <Resource
            name="UserDatabase"
            auth="Container"
            type="org.apache.catalina.UserDatabase"
            description="User database that can be updated and saved"
            factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
            pathname="conf/tomcat-users.xml"
        />

    </GlobalNamingResources>

    <!--
        A "Service" is a collection of one or more "Connectors" that share a
        single "Container" Note: A "Service" is not itself a "Container", so
        you may not define subcomponents such as "Valves" at this level.
        Documentation at /docs/config/service.html
    -->
    <Service name="Catalina">

        <!--
            The connectors will use a shared executor, you can define one or
            more named thread pools. For LabKey Server, a single shared pool
            will be used for all connectors.
        -->
        <Executor
            name="tomcatSharedThreadPool"
            namePrefix="catalina-exec-"
            maxThreads="300"
            minSpareThreads="25"
            maxIdleTime="20000"
        />

        <!-- Define HTTP connector -->
        <Connector
            port="$LABKEY_HTTP_PORT"
            redirectPort="$LABKEY_HTTPS_PORT"
            scheme="http"
            protocol="org.apache.coyote.http11.Http11AprProtocol"
            executor="tomcatSharedThreadPool"
            acceptCount="100"
            connectionTimeout="20000"
            disableUploadTimeout="true"
            enableLookups="false"
            maxHttpHeaderSize="8192"
            minSpareThreads="25"
            useBodyEncodingForURI="true"
            URIEncoding="UTF-8"
            compression="on"
            compressionMinSize="2048"
            noCompressionUserAgents="gozilla, traviata"
            compressableMimeType="text/html,text/xml,text/css,application/json"
        >
            <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        </Connector>


        <!-- Define HTTPS connector -->
        <Connector
            port="$LABKEY_HTTPS_PORT"
            scheme="https"
            secure="true"
            SSLEnabled="true"
            sslEnabledProtocols="TLSv1.2"
            sslProtocol="TLSv1.2"
            ciphers="TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA,
                     TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256,
                     TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256,
                     TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA,
                     TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384,
                     TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384,
                     TLS_ECDH_RSA_WITH_AES_128_CBC_SHA,
                     TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256,
                     TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256,
                     TLS_ECDH_RSA_WITH_AES_256_CBC_SHA,
                     TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384,
                     TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384,
                     TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,
                     TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,
                     TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
                     TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,
                     TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,
                     TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
                     TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
                     TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,
                     TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
                     TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
                     TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,
                     TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
            protocol="org.apache.coyote.http11.Http11AprProtocol"
            executor="tomcatSharedThreadPool"
            acceptCount="100"
            connectionTimeout="20000"
            clientAuth="false"
            disableUploadTimeout="true"
            enableLookups="false"
            maxHttpHeaderSize="8192"
            minSpareThreads="25"
            useBodyEncodingForURI="true"
            URIEncoding="UTF-8"
            compression="on"
            compressionMinSize="2048"
            noCompressionUserAgents="gozilla, traviata"
            compressableMimeType="text/html,text/xml,text/css,application/json"
            keystoreType="pkcs12"
            keystorePass="$TOMCAT_KEYSTORE_PASSWORD"
            keystoreFile="$TOMCAT_INSTALL_HOME/SSL/$TOMCAT_KEYSTORE_FILENAME"
            maxThreads="150"
        >
            <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        </Connector>

        <!--
             Define an AJP 1.3 Connector on port 8009 -->
        <!-- Disable AJP -->
        <!--
        <Connector port="8009" protocol="AJP/1.3" redirectPort="$LABKEY_HTTPS_PORT" />
        -->

        <!--
            An Engine represents the entry point (within Catalina) that
            processes every request. The Engine implementation for Tomcat stand
            alone analyzes the HTTP headers included with the request, and
            passes them on to the appropriate Host (virtual host).
            Documentation at /docs/config/engine.html
        -->
        <Engine name="Catalina" defaultHost="localhost">

            <!--
                Use the LockOutRealm to prevent attempts to guess user passwords
                via a brute-force attack
            -->
            <Realm className="org.apache.catalina.realm.LockOutRealm">

                <!--
                    This Realm uses the UserDatabase configured in the global JNDI
                    resources under the key "UserDatabase". Any edits
                    that are performed against this UserDatabase are immediately
                    available for use by the Realm.
                -->
                <Realm
                    className="org.apache.catalina.realm.UserDatabaseRealm"
                    resourceName="UserDatabase"
                />

            </Realm>

            <Host
                name="localhost"
                appBase="webapps"
                unpackWARs="true"
                autoDeploy="true"
            >

                <!--
                    pulls the remote IP from the XForward-For header
                -->
                <!-- Remote IP Valve -->
                <Valve className="org.apache.catalina.valves.RemoteIpValve" />

                <!--
                    Access log processes all example.
                    Documentation at: /docs/config/valve.html
                    Note: The pattern used is equivalent to using pattern="common"
                -->
                <Valve
                    className="org.apache.catalina.valves.AccessLogValve"
                    directory="logs"
                    prefix="localhost_access_log"
                    suffix=".txt"
                    resolveHosts="false"
                    pattern="%{org.apache.catalina.AccessLog.RemoteAddr}r %l %u %t &quot;%r&quot; %s %b %D %S &quot;%{Referer}i&quot; &quot;%{User-Agent}i&quot; %{LABKEY.username}s %q"
                />

            </Host>
        </Engine>
    </Service>
</Server>

SERVERXMLHERE
    ) >"$TomcatServerFile"
    chmod 600 "$TomcatServerFile"

    # create Tomcat context path ROOT.xml
    TomcatROOTXMLFile="$CATALINA_HOME/conf/Catalina/localhost/$TOMCAT_CONTEXT_PATH.xml"
    (
      /bin/cat <<ROOTXMLHERE
<?xml version='1.0' encoding='utf-8'?>
<Context docBase="$LABKEY_INSTALL_HOME/labkeywebapp" reloadable="true" crossContext="true">

    <Resource name="jdbc/labkeyDataSource" auth="Container"
        type="javax.sql.DataSource"
        username="$POSTGRES_USER"
        password="$POSTGRES_PASSWORD"
        driverClassName="org.postgresql.Driver"
        url="jdbc:postgresql://$POSTGRES_HOST/$POSTGRES_DB"
        accessToUnderlyingConnectionAllowed="true"
        initialSize="5"
        maxTotal="50"
        maxIdle="5"
        minIdle="4"
        testOnBorrow="true"
        testOnReturn="false"
        testWhileIdle="true"
        timeBetweenEvictionRunsMillis="60000"
        minEvictableIdleTimeMillis="300000"
        maxWaitMillis="120000"
        validationQuery="SELECT 1" />

    <Resource name="mail/Session" auth="Container"
        type="javax.mail.Session"
        mail.smtp.host="$SMTP_HOST"
        mail.smtp.user="anonymous"
        mail.smtp.port="25"/>

    <Loader loaderClass="org.labkey.bootstrap.LabkeyServerBootstrapClassLoader" />

    <!-- Encryption key for encrypted property store -->
    <Parameter name="EncryptionKey" value="$LABKEY_MEK" />


</Context>

ROOTXMLHERE
    ) >"$TomcatROOTXMLFile"
    chmod 600 "$TomcatROOTXMLFile"
    echo "Tomcat ROOT.xml file created at $TomcatROOTXMLFile"
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_INSTALL_HOME/"
    console_msg " Tomcat (Standard) has been installed and configured."
  fi

}

function step_alt_files_link() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # adds symlink for alternate labkey files root
  # e.g. adds symlink for /media/ebs_volume/files to /labkey/labkey/files
  # Alt files volume must be mounted and formatted
  if [ -f "${ALT_FILE_ROOT_HEAD}/${COOKIE_ALT_FILE_ROOT_HEAD}" ]; then
    create_req_dir "${ALT_FILE_ROOT_HEAD}/files"
    chown -R "${TOMCAT_USERNAME}.${TOMCAT_USERNAME}" "${ALT_FILE_ROOT_HEAD}/files/"
    ln -s "${ALT_FILE_ROOT_HEAD}/files" "$LABKEY_INSTALL_HOME/files"
  else
    # create default files root
    if [ ! -d "$LABKEY_INSTALL_HOME/files" ]; then
      create_req_dir "$LABKEY_INSTALL_HOME/files"
      chown -R "${TOMCAT_USERNAME}.${TOMCAT_USERNAME}" "$LABKEY_INSTALL_HOME/files/"
    fi
  fi
}

function step_start_labkey() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi
  # Enables the tomcat service and starts labkey
  sudo systemctl enable tomcat_lk.service
  sudo systemctl start tomcat_lk.service
}

function step_outro() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  echo "
    Thank you for installing LabKey!

    Access installed LabKey from ${LABKEY_BASE_SERVER_URL:-}:${LABKEY_HTTPS_PORT:-}
  "
}

#
# Main loop
#
function main() {

  step_intro

  step_check_if_root

  console_msg "Configuring default variables"
  step_default_envs

  step_required_envs
  console_msg "Detected OS Platform is: $(platform)"
  console_msg "Detected Platform Version is: $(platform_version)"

  console_msg "Applying OS pre-reqs"
  step_os_prereqs

  console_msg "Verifying required directories"
  step_create_required_paths
  console_msg "Finished verifying required directories"

  console_msg "Downloading LabKey"
  step_download

  console_msg "Creating LabKey Application Properties"
  step_create_app_properties

  console_msg "Creating default LabKey Start-up Properties"
  step_startup_properties

  console_msg "Configuring Postgresql"
  step_postgres_configure

  step_remote_db_provision

  console_msg "Configuring Tomcat user"
  step_tomcat_user

  console_msg "Configuring Self Signed Certificate"
  step_tomcat_cert

  console_msg "Configuring LabKey"
  step_configure_labkey

  console_msg "Configuring Embedded Tomcat Service"
  step_tomcat_service_embedded

  console_msg "Configuring Standard Tomcat Service"
  step_tomcat_service_standard

  console_msg "Configuring Alt Files Root Link"
  step_alt_files_link

  step_start_labkey

  step_outro
}

# Main function called here
if [ -z "${SKIP_MAIN:-}" ]; then
  main
fi
