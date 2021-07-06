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
  bold=$(tput bold)
  normal=$(tput sgr0)
  echo "${normal}---------${bold} $1 ${normal} ---------"
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

  printf '%s\n\n%s' \
    "
    ${PRODUCT} CLI Install Script
  " \
    '
     __
     ||  |  _ |_ |/ _
    (__) |_(_||_)|\(/_\/
                      /
  '
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

}

function step_os_prereqs() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

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
    # Add adoptopenjdk repo
    DEB_JDK_REPO="https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/"
    if ! grep -q "$DEB_JDK_REPO" "/etc/apt/sources.list"; then
      wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
      sudo add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/
    fi

    sudo apt-get update
    sudo apt-get install -y "$ADOPTOPENJDK_VERSION"

    ;;

  _*)
    echo "can't install postgres on unrecognized platform: \"$(platform)\""
    ;;
  esac

}

function step_download() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # attempt to download all binaries
  #   fail if URLs incorrect/download fails
  #   fail if download succeeds but it 0 bytes
  # (option) verify checksums
}

function step_create_app_properties() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  # application properties depends on the ${LABKEY_APP_HOME} directory - error if no directory exists
  if [ ! -d "${LABKEY_APP_HOME}" ]; then
    console_msg "ERROR! - The ${LABKEY_APP_HOME} does not exist - I gotta put this file somewhere!"
  else
    NewFile="${LABKEY_APP_HOME}/application.properties"
    (
      /bin/cat <<-APP_PROPS_HERE
						# debug=true
						# trace=true

						server.tomcat.basedir=${TOMCAT_BASE_DIR:-/}

						server.port=${LABKEY_PORT:-8443}

						spring.main.log-startup-info=true

						spring.main.banner-mode=off

						spring.application.name=labkey
						server.servlet.application-display-name=labkey

						# logging.pattern.console=
						logging.pattern.console=%clr(%d{yyyy-MM-dd HH:mm:ss.SSS}){faint} E %clr(%-5.5p) %clr(%5.5replace(%p){'.+', ${PID:-}}){magenta} %clr(---){faint} %clr([%15.15t]){faint} %clr(${LOGGER_PATTERN:-%-40.40logger{39}}){cyan} %clr(:){faint} %m%n%wEx

						logging.level.root=WARN

						# custom tomcat group
						logging.group.tomcat=org.apache.catalina,org.apache.coyote,org.apache.tomcat
						logging.level.tomcat=${LOG_LEVEL_TOMCAT:-OFF}

						logging.level.org.apache.coyote.http2=OFF

						# default groups
						logging.level.web=${LOG_LEVEL_SPRING_WEB:-OFF}
						logging.level.sql=${LOG_LEVEL_SQL:-OFF}

						logging.level.net.sf.ehcache=ERROR

						# logging.level.org.apache=TRACE
						# logging.level.org.apache.catalina.core.Catalina=TRACE
						logging.level.org.apache.catalina.core.ContainerBase.[Tomcat].[localhost]=TRACE
						# logging.level.org.apache.catalina.core=TRACE
						# logging.level.org.apache.catalina.LifecycleException=TRACE
						logging.level.org.apache.catalina.loader.WebappClassLoaderBase=OFF
						# logging.level.org.apache.catalina.session=TRACE
						# logging.level.org.apache.catalina.startup.ContextConfig=OFF
						# logging.level.org.apache.catalina.util.LifecycleBase=TRACE
						# logging.level.org.apache.catalina.util=TRACE
						# logging.level.org.apache.catalina=TRACE
						# logging.level.org.apache.coyote=TRACE
						# logging.level.org.apache.logging.log4j.core.net=TRACE
						# logging.level.org.apache.naming=OFF
						logging.level.org.apache.tomcat.util.IntrospectionUtils=OFF
						# logging.level.org.apache.tomcat.util.net=TRACE
						logging.level.org.apache.tomcat.util.scan=OFF
						# logging.level.org.apache.tomcat.util=TRACE
						logging.level.org.labkey.embedded.LabKeyServer=DEBUG
						logging.level.org.springframework.boot.autoconfigure.logging.ConditionEvaluationReportLoggingListener=OFF
						# logging.level.org.springframework.boot.autoconfigure=OFF
						# logging.level.org.springframework.boot.context.embedded.tomcat.TomcatEmbeddedServletContainer=TRACE
						# logging.level.org.springframework.boot.web.embedded.tomcat.TomcatWebServer=TRACE
						# logging.level.org.springframework.boot.web.servlet.context=TRACE
						# logging.level.org.springframework.boot.web.servlet=WARN
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

						# logging.level.org.apache.catalina.loader.WebappClassLoaderBase=INFO
						logging.level.org.apache.jasper.servlet.TldScanner=WARN
						logging.level.org.apache.tomcat.util.digester.Digester=INFO

						# logging.level.org.apache.tomcat.util.scan.StandardJarScanner=INFO
						# logging.level.org.springframework.boot.autoconfigure.condition=INFO
						# logging.level.org.springframework.core.env.PropertySourcesPropertyResolver=INFO

						context.dataSourceName[0]=jdbc/labkeyDataSource
						context.driverClassName[0]=org.postgresql.Driver
						context.url[0]=jdbc:postgresql://${POSTGRES_HOST:-localhost}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-${POSTGRES_USER}}${POSTGRES_PARAMETERS:-}
						context.username[0]=${POSTGRES_USER:-postgres}
						context.password[0]=${POSTGRES_PASSWORD:-}

						# context.dataSourceName[1]=jdbc/@@extraJdbcDataSource@@
						# context.driverClassName[1]=@@extraJdbcDriverClassName@@
						# context.url[1]=@@extraJdbcURL@@
						# context.username[1]=@@extraJdbcUser@@
						# context.password[1]=@@extraJdbcPassword@@

						# TODO: console access logs w/o symlink
						# server.tomcat.accesslog.enabled=true
						# server.tomcat.accesslog.directory=/dev
						# server.tomcat.accesslog.prefix=stdout
						# server.tomcat.accesslog.buffered=false
						# server.tomcat.accesslog.suffix=
						# server.tomcat.accesslog.pattern=%{org.apache.catalina.AccessLog.RemoteAddr}r %l %u %t "%r" %s %b %D %S "%{Referer}i" "%{User-Agent}i" %{LABKEY.username}s %q

						server.tomcat.accesslog.directory=/tmp
						server.tomcat.accesslog.enabled=true
						server.tomcat.accesslog.prefix=access
						server.tomcat.accesslog.suffix=.log
						server.tomcat.accesslog.rotate=false
						server.tomcat.accesslog.pattern=%{org.apache.catalina.AccessLog.RemoteAddr}r %l %u %t "%r" %s %b %D %S "%{Referer}i" "%{User-Agent}i" %{LABKEY.username}s %q

						server.http2.enabled=true

						server.ssl.enabled=true

						server.ssl.ciphers=${TOMCAT_SSL_CIPHERS:-HIGH:!ADH:!EXP:!SSLv2:!SSLv3:!MEDIUM:!LOW:!NULL:!aNULL}
						server.ssl.enabled-protocols=${TOMCAT_SSL_ENABLED_PROTOCOLS:-TLSv1.3,+TLSv1.2}
						server.ssl.protocol=${TOMCAT_SSL_PROTOCOL:-TLS}


						# must match values in entrypoint.sh
						server.ssl.key-alias=${TOMCAT_KEYSTORE_ALIAS:-tomcat}
						server.ssl.key-store=${LABKEY_APP_HOME}/${TOMCAT_KEYSTORE_FILENAME:-labkey.p12}
						# server.ssl.key-store-password=${TOMCAT_KEYSTORE_PASSWORD}
						server.ssl.key-store-type=${TOMCAT_KEYSTORE_FORMAT:-PKCS12}

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

						management.endpoints.web.exposure.include=health
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
    console_msg " ERROR: LabKey Install Home directory does not exist! "
    return 1
  fi

  if [ -d "$LABKEY_INSTALL_HOME" ]; then
    if [ ! -d "$LABKEY_INSTALL_HOME/startup" ]; then
      create_req_dir "$LABKEY_INSTALL_HOME/startup"
    fi
    # create startup properties file
    NewFile="$LABKEY_INSTALL_HOME/startup/70_basic-startup.properties"
    (
      /bin/cat <<-STARTUP_PROPS_HERE
				LookAndFeelSettings.companyName="${LABKEY_COMPANY_NAME}"
				#LookAndFeelSettings.reportAProblemPath="https://www.labkey.org/hosted-support.url"
				LookAndFeelSettings.systemDescription="${LABKEY_SYSTEM_DESCRIPTION}"
				LookAndFeelSettings.systemEmailAddress="${LABKEY_SYSTEM_EMAIL_ADDRESS}"
				LookAndFeelSettings.systemShortName="${LABKEY_SYSTEM_SHORT_NAME}"
				SiteRootSettings.siteRootFile="${LABKEY_FILES_ROOT}"
				SiteSettings.baseServerURL="${LABKEY_BASE_SERVER_URL}"
				SiteSettings.defaultDomain="${LABKEY_DEFAULT_DOMAIN}"
				SiteSettings.pipelineToolsDirectory="${LABKEY_INSTALL_HOME}"
				SiteSettings.sslPort="${LABKEY_PORT}"
				SiteSettings.sslRequired="true"

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

  step_required_envs
  console_msg "Detected OS Platform is: $(platform) "
  console_msg "Detected Platform Version is: $(platform_version) "
  step_os_prereqs
  console_msg " Verifying required directories "
  step_create_required_paths
  console_msg " Finished verifying required directories "

  console_msg " Creating LabKey Application Properties "
  step_create_app_properties
  console_msg " Creating default LabKey Start-up Properties "
  step_startup_properties

  step_postgres_configure
  step_download

  step_outro
}

# Main function called here
if [ -z "${LABKEY_INSTALL_SKIP_MAIN:-}" ]; then
  main
fi
