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

# must be root or launch script with sudo
if [[ $(whoami) != root ]]; then
  echo Please run this script as root or using sudo
  exit
fi

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
  local release_dir='/etc'

  if [ -n "${SHUNIT_VERSION:-}" ]; then
    release_dir="${SHUNIT_TMPDIR:-}"
  fi

  grep -s "^${1}=" "${release_dir}/os-release" | cut -d'=' -f2- |
    tr -d '\n' | xargs | tr '[:upper:]' '[:lower:]'
}

function _lsb_release() {
  local flag="$1"

  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -s "-${flag}" | tr '[:upper:]' '[:lower:]'
  fi
}

function platform() {
  if ! _os_release 'ID'; then
    _lsb_release 'i'
  fi | xargs
}

function platform_version() {
  if ! _os_release 'VERSION_ID'; then
    _lsb_release 'r'
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

function step_default_envs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # Provides default values for environment variables - override these values by passing in your own values via
  # environment variables in the shell used to launch this script.

  # Java env vars
  ADOPTOPENJDK_VERSION="${ADOPTOPENJDK_VERSION:-adoptopenjdk-16-hotspot}"

  # set default heap min/max to 50% (w/ <= 8G) or 75% of total mem
  DEFAULT_JAVA_HEAP_SIZE="$(
    total="$(free -m  | grep ^Mem | tr -s ' ' | cut -d ' ' -f 2)"

    if [ "$total" -ge 8192 ]; then
      heap_modifier='75'
    else
      heap_modifier='50'
    fi

    echo -n "$(( total * heap_modifier / 100 ))M"
  )"

  JAVA_HEAP_SIZE="${JAVA_HEAP_SIZE:-${DEFAULT_JAVA_HEAP_SIZE}}"

  # LabKey env vars
  LABKEY_COMPANY_NAME="${LABKEY_COMPANY_NAME:-LabKey}"
  LABKEY_SYSTEM_DESCRIPTION="${LABKEY_SYSTEM_DESCRIPTION:-labkey demo deployment}"
  LABKEY_SYSTEM_SHORT_NAME="${LABKEY_SYSTEM_SHORT_NAME:-demo}"
  LABKEY_DEFAULT_DOMAIN="${LABKEY_DEFAULT_DOMAIN:-labkey.com}"
  LABKEY_SYSTEM_EMAIL_ADDRESS="${LABKEY_SYSTEM_EMAIL_ADDRESS:-donotreply@${LABKEY_DEFAULT_DOMAIN}}"
  LABKEY_BASE_SERVER_URL="${LABKEY_BASE_SERVER_URL:-http://localhost}"
  LABKEY_APP_HOME="${LABKEY_APP_HOME:-/labkey}"
  LABKEY_INSTALL_HOME="${LABKEY_INSTALL_HOME:-$LABKEY_APP_HOME/labkey}"
  LABKEY_SRC_HOME="${LABKEY_SRC_HOME:-$LABKEY_APP_HOME/src/labkey}"
  LABKEY_FILES_ROOT="${LABKEY_FILES_ROOT:-${LABKEY_INSTALL_HOME}/files}"
  LABKEY_VERSION="${LABKEY_VERSION:-21.7.0}"
  LABKEY_DISTRIBUTION="${LABKEY_DISTRIBUTION:-community}"
  LABKEY_DIST_URL="${LABKEY_DIST_URL:-https://lk-binaries.s3.us-west-2.amazonaws.com/downloads/release/community/21.7.0/LabKey21.7.0-2-community-embedded.tar.gz}"
  LABKEY_DIST_FILENAME="${LABKEY_DIST_FILENAME:-LabKey21.7.0-2-community-embedded.tar.gz}"
  LABKEY_DIST_DIR="${LABKEY_DIST_DIR:-${LABKEY_DIST_FILENAME::-16}}"
  LABKEY_PORT="${LABKEY_PORT:-8443}"
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

  TOMCAT_SSL_CIPHERS="${TOMCAT_SSL_CIPHERS:-HIGH:!ADH:!EXP:!SSLv2:!SSLv3:!MEDIUM:!LOW:!NULL:!aNULL}"
  TOMCAT_SSL_ENABLED_PROTOCOLS="${TOMCAT_SSL_ENABLED_PROTOCOLS:-TLSv1.3,+TLSv1.2}"
  TOMCAT_SSL_PROTOCOL="${TOMCAT_SSL_PROTOCOL:-TLS}"

  # Used for Standard Tomcat installs only
  TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.50}"
  TOMCAT_URL="http://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
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
    # Add adoptopenjdk repo
    if [ ! -f "/etc/yum.repos.d/adoptopenjdk.repo" ]; then
      NewFile="/etc/yum.repos.d/adoptopenjdk.repo"
      (
        /bin/cat <<-AMZN_JDK_HERE
				[AdoptOpenJDK]
				name=AdoptOpenJDK
				baseurl=http://adoptopenjdk.jfrog.io/adoptopenjdk/rpm/amazonlinux/\$releasever/\$basearch
				enabled=1
				gpgcheck=1
				gpgkey=https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public
			AMZN_JDK_HERE
      ) >"$NewFile"
    fi
    sudo yum update -y
    sudo yum install -y "$ADOPTOPENJDK_VERSION"
    ;;

  _centos)
    sudo yum update -y
    sudo yum install epel-release vim wget -y
    # Add adoptopenjdk repo
    if [ ! -f "/etc/yum.repos.d/adoptopenjdk.repo" ]; then
      NewFile="/etc/yum.repos.d/adoptopenjdk.repo"
      (
        /bin/cat <<-AMZN_JDK_HERE
				[AdoptOpenJDK]
				name=AdoptOpenJDK
				baseurl=http://adoptopenjdk.jfrog.io/adoptopenjdk/rpm/centos/\$releasever/\$basearch
				enabled=1
				gpgcheck=1
				gpgkey=https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public
			AMZN_JDK_HERE
      ) >"$NewFile"
    fi
    sudo yum install -y tomcat-native apr fontconfig "$ADOPTOPENJDK_VERSION"
    ;;

  _ubuntu)
    # ubuntu stuff here
    export DEBIAN_FRONTEND=noninteractive
    TOMCAT_LIB_PATH="/usr/lib/x86_64-linux-gnu"
    # Add adoptopenjdk repo
    DEB_JDK_REPO="https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/"
    if ! grep -q "$DEB_JDK_REPO" "/etc/apt/sources.list"; then
      wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
      sudo add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/
    fi

    sudo apt-get update
    sudo apt-get install -y "$ADOPTOPENJDK_VERSION" libtcnative-1 libapr1
    sudo apt-get -y dist-upgrade
    ;;

  _*)
    echo "can't install adoptopenjdk on unrecognized platform: \"$(platform)\""
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
						# debug=true
						# trace=true

						server.tomcat.basedir=${TOMCAT_INSTALL_HOME}

						server.port=${LABKEY_PORT}

						spring.main.log-startup-info=true

						spring.main.banner-mode=off

						spring.application.name=labkey
						server.servlet.application-display-name=labkey

						logging.level.root=WARN

						# custom tomcat group
						logging.group.tomcat=org.apache.catalina,org.apache.coyote,org.apache.tomcat
						logging.level.tomcat=${LOG_LEVEL_TOMCAT}

						logging.level.org.apache.coyote.http2=OFF

						# default groups
						logging.level.web=${LOG_LEVEL_SPRING_WEB}
						logging.level.sql=${LOG_LEVEL_SQL}

						logging.level.net.sf.ehcache=ERROR
						logging.level.org.springframework.boot=INFO

						logging.level.org.springframework.jdbc.core=WARN
						logging.level.org.hibernate.SQL=WARN
						logging.level.org.jooq.tools.LoggerListener=WARN
						logging.level.org.springframework.core.codec=WARN
						logging.level.org.springframework.http=WARN
						logging.level.org.springframework.web=WARN
						logging.level.org.springframework.boot.actuate.endpoint.web=WARN
						logging.level.org.springframework.boot.web.servlet.ServletContextInitializerBeans=WARN
						logging.level.org.springframework.boot=WARN

						logging.level.org.apache.jasper.servlet.TldScanner=WARN
						logging.level.org.apache.tomcat.util.digester.Digester=INFO

						context.dataSourceName[0]=jdbc/labkeyDataSource
						context.driverClassName[0]=org.postgresql.Driver
						context.url[0]=jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}${POSTGRES_PARAMETERS}
						context.username[0]=${POSTGRES_USER}
						context.password[0]=${POSTGRES_PASSWORD}

						server.tomcat.accesslog.directory=${LABKEY_INSTALL_HOME}/logs
						server.tomcat.accesslog.enabled=true
						server.tomcat.accesslog.prefix=access
						server.tomcat.accesslog.suffix=.log
						server.tomcat.accesslog.rotate=false
						server.tomcat.accesslog.pattern=%{org.apache.catalina.AccessLog.RemoteAddr}r %l %u %t "%r" %s %b %D %S "%{Referer}i" "%{User-Agent}i" %{LABKEY.username}s %q

						server.http2.enabled=true
						server.ssl.enabled=true

						server.ssl.ciphers=${TOMCAT_SSL_CIPHERS}
						server.ssl.enabled-protocols=${TOMCAT_SSL_ENABLED_PROTOCOLS}
						server.ssl.protocol=${TOMCAT_SSL_PROTOCOL}

						server.ssl.key-alias=${TOMCAT_KEYSTORE_ALIAS}
						server.ssl.key-store=${TOMCAT_KEYSTORE_BASE_PATH}/${TOMCAT_KEYSTORE_FILENAME}
						server.ssl.key-store-password=${TOMCAT_KEYSTORE_PASSWORD}
						server.ssl.key-store-type=${TOMCAT_KEYSTORE_FORMAT}

						context.masterEncryptionKey=${LABKEY_MEK}
						context.serverGUID=${LABKEY_GUID}

						#
						# as of time of writing, this cannot be changed via app props but is needed for
						# management.endpoints.web.base-path below
						#
						server.servlet.context-path=/_

						server.error.whitelabel.enabled=false

						mail.smtpHost=${SMTP_HOST}
						mail.smtpUser=${SMTP_USER}
						mail.smtpPort=${SMTP_PORT}
						mail.smtpPassword=${SMTP_PASSWORD}
						mail.smtpAuth=${SMTP_AUTH}
						mail.smtpFrom=${SMTP_FROM}
						mail.smtpStartTlsEnable=${SMTP_STARTTLS}

						management.endpoints.web.base-path=/

						management.endpoints.enabled-by-default=false
						management.endpoint.health.enabled=true
						management.endpoint.info.enabled=true

						management.endpoints.web.exposure.include=health,info
						management.endpoints.jmx.exposure.exclude=*

						management.endpoint.env.keys-to-sanitize=.*user.*,.*pass.*,secret,key,token,.*credentials.*,vcap_services,sun.java.command,.*key-store.*

						info.labkey.version=${LABKEY_VERSION}
						info.labkey.distribution=${LABKEY_DISTRIBUTION}

						server.tomcat.max-threads=50

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
				SiteSettings.sslPort=${LABKEY_PORT}
				SiteSettings.sslRequired=true

				STARTUP_PROPS_HERE
    ) >"$NewFile"
  fi
}

function step_postgres_configure() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  case "_$(platform)" in
  _amzn)

    if [ "$POSTGRES_SVR_LOCAL" == "TRUE" ]; then
      sudo amazon-linux-extras enable postgresql11 epel
      #amazon-linux-extras install epel
      sudo yum clean metadata
      sudo yum update -y
      sudo yum install epel-release postgresql.x86_64 postgresql-server.x86_64 -y
      # TODO: These are pre-reqs for Amazon Linux - Move to the pre-reqs function
      sudo yum install tomcat-native.x86_64 apr fontconfig -y

      if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then
        /usr/bin/postgresql-setup --initdb
      fi
      sudo systemctl enable postgresql
      sudo systemctl start postgresql
      sudo -u postgres psql -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
      sudo -u postgres psql -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
      sudo -u postgres psql -c "revoke all on database $POSTGRES_DB from public;"
      sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/data/pg_hba.conf
      sudo systemctl restart postgresql
      console_msg "Postgres Server and Client Installed ..."
    else
      sudo amazon-linux-extras enable postgresql11 epel
      #amazon-linux-extras install epel
      sudo yum clean metadata
      sudo yum install epel-release postgresql.x86_64 -y
      # TODO: These are pre-reqs for Amazon Linux - Move to the pre-reqs function
      sudo yum install tomcat-native.x86_64 apr fontconfig -y
      console_msg "Postgres Client Installed ..."
    fi
    ;;

  _centos)
    if [ ! -e "/etc/yum.repos.d/pgdg-redhat-all.repo" ]; then
      sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
      sudo yum clean metadata
      sudo yum update -y
    fi

    if [ "$POSTGRES_SVR_LOCAL" == "TRUE" ]; then
      sudo yum install -y postgresql11-server

      if [ ! -f /var/lib/pgsql/11/data/PG_VERSION ]; then
        /usr/pgsql-11/bin/postgresql-11-setup initdb
      fi
      sudo systemctl enable postgresql-11
      sudo systemctl start postgresql-11
      sudo -u postgres psql -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
      sudo -u postgres psql -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
      sudo -u postgres psql -c "revoke all on database $POSTGRES_DB from public;"
      sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/11/data/pg_hba.conf
      sudo systemctl restart postgresql-11
      console_msg "Postgres Server and Client Installed ..."
    else
      sudo yum install -y postgresql11
      console_msg "Postgres Client Installed ..."
    fi
    ;;

  _ubuntu)
    # TODO add platform version for 20.04 only
    # for version 11
    # Create the file repository configuration:
    # sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

    # Import the repository signing key:
    # wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo apt-get update
    # Postgresql 12 included in Ubuntu 20.04
    if [ "$POSTGRES_SVR_LOCAL" == "TRUE" ]; then
      sudo apt-get -y install postgresql-12
      # Not needed for conical postgresql package
      #if [ ! -f /var/lib/postgresql/12/main/PG_VERSION ]; then
      #  /usr/pgsql-11/bin/postgresql-11-setup initdb
      #fi

      sudo systemctl enable postgresql
      sudo systemctl start postgresql
      sudo -u postgres psql -c "create user $POSTGRES_USER password '$POSTGRES_PASSWORD';"
      sudo -u postgres psql -c "create database $POSTGRES_DB with owner $POSTGRES_USER;"
      sudo -u postgres psql -c "revoke all on database $POSTGRES_DB from public;"
      # This may not be needed on ubuntu
      #sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' /etc/postgresql/12/main/pg_hba.conf
      sudo systemctl restart postgresql
      console_msg "Postgres Server and Client Installed ..."
    else
      sudo apt-get -y install postgresql-client-12
      console_msg "Postgres Client Installed ..."
    fi

    ;;

  _*)
    echo "can't install postgres on unrecognized platform: \"$(platform)\""
    ;;
  esac

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
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${LABKEY_APP_HOME}"
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${LABKEY_SRC_HOME}"
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${LABKEY_INSTALL_HOME}"
  chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "${TOMCAT_INSTALL_HOME}"

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
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_INSTALL_HOME"
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_TMP_DIR"
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$LABKEY_INSTALL_HOME"
    rm "${LABKEY_APP_HOME}/src/apache-tomcat-$TOMCAT_VERSION.tar.gz"
    rm -Rf "${LABKEY_APP_HOME}/src/apache-tomcat-$TOMCAT_VERSION"
    chmod 0700 "${CATALINA_HOME}/conf/Catalina/localhost"

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
				Environment="CATALINA_OPTS=-Djava.library.path=$TOMCAT_LIB_PATH -Djava.awt.headless=true -Duser.timezone=$TOMCAT_TIMEZONE -Xms$JAVA_HEAP_SIZE -Xmx$JAVA_HEAP_SIZE -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$TOMCAT_TMP_DIR -Djava.net.preferIPv4Stack=true"
				Environment="CATALINA_TMPDIR=$TOMCAT_TMP_DIR"


				ExecStart=$TOMCAT_INSTALL_HOME/bin/catalina.sh start
				ExecStop=$TOMCAT_INSTALL_HOME/bin/catalina.sh stop
				SuccessExitStatus=0 143
				Restart=on-failure
				RestartSec=2

				User=tomcat
				Group=tomcat

				[Install]
				WantedBy=multi-user.target
				HERE_STD_TOMCAT_SERVICE
    ) >$NewFile

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
            port="8080"
            redirectPort="8443"
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
            port="8443"
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
        <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" />
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

    # create Tomcat ROOT.xml
    TomcatROOTXMLFile="$CATALINA_HOME/conf/Catalina/localhost/ROOT.xml"
    (
      /bin/cat <<ROOTXMLHERE
<?xml version='1.0' encoding='utf-8'?>
<Context docBase="/labkey/labkey/labkeywebapp" reloadable="true" crossContext="true">

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
        validationQuery="SELECT 1" />

    <Resource name="mail/Session" auth="Container"
        type="javax.mail.Session"
        mail.smtp.host="$SMTP_HOST"
        mail.smtp.user="anonymous"
        mail.smtp.port="25"/>

    <Loader loaderClass="org.labkey.bootstrap.LabkeyServerBootstrapClassLoader" />

    <!-- Encryption key for encrypted property store -->
    <Parameter name="MasterEncryptionKey" value="$LABKEY_MEK" />


</Context>

ROOTXMLHERE
    ) >"$TomcatROOTXMLFile"
    chmod 600 "$TomcatROOTXMLFile"
    echo "Tomcat ROOT.xml file created at $TomcatROOTXMLFile"
    chown -R "$TOMCAT_USERNAME"."$TOMCAT_USERNAME" "$TOMCAT_INSTALL_HOME"
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
    chown -R "${TOMCAT_USERNAME}.${TOMCAT_USERNAME}" "${ALT_FILE_ROOT_HEAD}/files"
    ln -s "${ALT_FILE_ROOT_HEAD}/files" "$LABKEY_INSTALL_HOME/files"
  else
    # create default files root
    if [ ! -d "$LABKEY_INSTALL_HOME/files" ]; then
      create_req_dir "$LABKEY_INSTALL_HOME/files"
      chown -R "${TOMCAT_USERNAME}.${TOMCAT_USERNAME}" "$LABKEY_INSTALL_HOME/files"
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

    Access installed LabKey from ${LABKEY_BASE_SERVER_URL:-}:${LABKEY_PORT:-}
  "
}

#
# Main loop
#
function main() {

  step_intro

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
if [ -z "${LABKEY_INSTALL_SKIP_MAIN:-}" ]; then
  main
fi
