# `install-script`

A repository for shell scripts that aid in the installation of LabKey products and services.

## Invocation

To avoid the complexity of parsing CLI flags in bash or with `getopts`, and to maximize the portability of the script, all inputs to the script should be supplied as Environment Variables. So invocation is expected to look like:

```bash
LABKEY_COMPANY_NAME='Megadodo Publications' ... ./install-labkey.bash
```

And hopefully in the not-to-distant future:

```bash
curl -sSL https://install.hclq.sh | bash
```

All scripts derived from this repo's `template.sh` script should support a `DEBUG` flag that enables `set -x` when set to a value other than an empty string:

```bash
DEBUG=1 ./install-labkey.bash
```

## Development

Installation of LabKey products and service can be described in "steps" and that's the fundamental abstraction this script/repo strive to leverage.

You'll find the install script segmented into Bash functions which serve as these "steps" and are named as such. The collected body of "step functions" are then called in the main loop of the script in an order that makes sense.

As with any Bash script, the guiding principles should be to **fail early** and to **provide sensible defaults** that would allow someone to run the script without any input, and receive a functional (albeit generically configured) instance of the product.

Some generic functions designed to keep logic within the script manageable are provided: `platform()` and `platform_version()` which will inspect `/etc/os-release` and/or execute `lsb_release` to identify the OS and the OS version:

```bash
if [[ "$(platform)" == 'ubuntu' ]]; then
  echo 'do something specific to Ubuntu'
fi
```

```bash
case "_$(platform)" in
  _alpine)
    sudo apk update
    sudo apk add sl
    ;;
  _ubuntu)
    sudo apt-get update
    sudo apt-get install sl
    ;;
  _*)
    echo "can't install sl on unrecognized platform: \"$(platform)\""
    ;;
esac
```

The tests and other shells scripts may use the `LABKEY_INSTALL_SKIP_MAIN` environment variable when `source`ing this script to allow for setting all of the script's functions without executing them.

Similarly, a general mechanism for skipping "step functions" has been included that allows users to provide the step's name in an environment variable of the shape: `LABKEY_INSTALL_SKIP_<step fn name>_STEP` which will cause the script to.. you guessed it.. skip that step. For example, to skip the intro step function and void printing the LabKey ascii art: `LABKEY_INSTALL_SKIP_INTRO_STEP=1 ./install-labkey.sh` This is accomplished by the `_skip_step()` function which should be included as the first line in any "step functions":

```bash
function step_example() {
  if _skip_step "${FUNCNAME[0]/step_/}"; then return 0; fi

  echo 'an example function'
}
```

Setting `LABKEY_INSTALL_SKIP_EXAMPLE_STEP=1` would cause the script in the above example to void printing "an example step".

### Writing Tests

This repo uses an "xUnit"-style testing testing tool called [`shunit2`](https://github.com/kward/shunit2). `shunit2` was chosen over `bats` owning to the lack of strict mode support in `bats` when sourcing other scripts and their functions. See also: [Support for "unofficial strict mode"?](https://github.com/sstephenson/bats/issues/171).

`shunit2` uses "assertions" as the currency with which code functionality is purchased. Some common, self explanatory assertions are: `assertEquals`, `assertNull`, and `assertTrue`. Assertions generally follow the format: `<assertionFunction> <message upon failure> <expected results> <actual results>` and in true Bash fashion, mostly operate on strings. E.g.: `assertEquals 'values not equal' 'apple' "$(fn_which_prints_pear)"` would fail assuming `fn_which_prints_pear` would print "pear".

Tests for specific functionality of a given installation "step" can be written to a test script file named after that steps (as with `step_intro_test.sh`). And tests for internal functions can be written to the `internals.sh` script file.

Try to avoid writing tests that verify the functionality of reliable tools like `mkdir`.

### Running tests Locally

An advantage of having a "purely bash" testing framework is the ability to just add the `shunit2` source file into one's repo, so you'll both find it within the `test` directory and excluded from shells script linting in the github actions.

Since a copy of the `shunit2` source code exists in this repo, the tests are self-contained and assuming they have execute permissions, can be run simply as:

```bash
./test/internals.sh
```

A small helper script designed to run all script files ending in `.sh` in the `test` directory has been included: `runner.sh`. And is used in the github actions. This can also be executed to run all the tests.

### Running Github Actions Locally

If you don't wish to install `shellcheck`/`shfmt`/`yamllint`/etc. locally, you can run the github actions locally using a tool called [`act`](https://github.com/nektos/act) (available via homebrew on mac):

```bash
act -s 'GITHUB_TOKEN=<github token>'

# | test_platform_lsb_release
# | test_platform_version_lsb_release
# |
# | Ran 2 tests.
# |
# | OK
# | test_step_skipping
# |
# | Ran 1 test.
# |
# | OK
```

## LabKey Install Script Usage Examples

As noted above, for portability and maintainability, install scripts in this repo expected input to supplied as environment variables. Below you'll find a couple examples of how to invoke install scripts while supplying those environment variables.

### Example 1: Use environment variables on the command line as inputs to the installation script

Environment variable inputs can be provided as part of the command line when invoking the installation script.

```bash
sudo su -
LABKEY_COMPANY_NAME='Megadodo Publications' LABKEY_DEFAULT_DOMAIN='megadodo.com' LABKEY_BASE_SERVER_URL='https://megadodo.com' LABKEY_VERSION='21.7.1' ./install-labkey.bash
```

Another option for achieving super-user privileges while maintaining environment variables is `sudo`'s "-E" flag. Which passes the current environment through to the command you're using `sudo` to run:

```bash
export LABKEY_COMPANY_NAME='Megadodo Publications' LABKEY_DEFAULT_DOMAIN='megadodo.com' LABKEY_BASE_SERVER_URL='https://megadodo.com' LABKEY_VERSION='21.7.1'
sudo -E ./install-labkey.bash
```

### Example 2: Use a source script to provide Environment variables inputs

The installation scripts `install-labkey.bash` and `install-wcp.bash` utilize a myriad of installation variables. The majority of which have reasonable defaults. (See the documented Inputs section below for more details on the available installation variables.) However, a minimum set of installation variables must be supplied to instantiate systems successfully. To ease installation some sample environment files have been provided. Please see the included `sample_embedded_envs.sh`, `sample_std_tomcat_envs.sh`, and `sample_wcp_envs.sh` in the repo. Using one of these users can edit or create their own environments file and invoke the installation script as follows:

```bash
sudo su -
source ./sample_embedded_envs.sh
./install-labkey.bash
```

### WCP Install Script Usage

The WCP installation script `install-wcp.bash` depends on the `install-labkey.bash` script for many common installation functions. The URL to this script is a required input. To ease installation a sample environment file has been provided.

```bash
sudo su -
source ./sample_wcp_envs.sh
./install-wcp.bash
```

## Inputs Reference

The following tables list the available input variables and default values. In the table below, `NULL` is the Bash definition of "null". E.g.: an empty string.

### General Install Inputs

| Name                        | Description                                                       | Default value                                                                                                                                                                                                  | Required |
| --------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| JAVA_HEAP_SIZE              | Java heap size                                                    | Input value or calculated >8GB = 75% of RAM, <8GB = 50% of RAM                                                                                                                                                 | no       |
| LABKEY_COMPANY_NAME         | Company name used in application settings                         | LabKey                                                                                                                                                                                                         | no       |
| LABKEY_SYSTEM_DESCRIPTION   | System description                                                | labkey demo deployment                                                                                                                                                                                         | no       |
| LABKEY_SYSTEM_SHORT_NAME    | Short name used in application settings                           | demo                                                                                                                                                                                                           | no       |
| LABKEY_DEFAULT_DOMAIN       | Default domain used in application settings                       | labkey.com                                                                                                                                                                                                     | yes      |
| LABKEY_SYSTEM_EMAIL_ADDRESS | Default email used for system notifications                       | donotreply@${LABKEY_DEFAULT_DOMAIN}                                                                                                                                                                            | no       |
| LABKEY_BASE_SERVER_URL      | System URL                                                        | <http://localhost>                                                                                                                                                                                             | yes      |
| LABKEY_APP_HOME             | Base path for LabKey installation                                 | /labkey                                                                                                                                                                                                        | yes      |
| LABKEY_INSTALL_HOME         | Path for LabKey web application files                             | $LABKEY_APP_HOME/labkey                                                                                                                                                                                        | no       |
| LABKEY_SRC_HOME             | Path used for downloaded install components                       | $LABKEY_APP_HOME/src/labkey                                                                                                                                                                                    | no       |
| LABKEY_FILES_ROOT           | LabKey file root path for LabKey application                      | ${LABKEY_INSTALL_HOME}/files                                                                                                                                                                                   | no       |
| LABKEY_VERSION              | Version of LabKey to install                                      | 21.7.0                                                                                                                                                                                                         | yes      |
| LABKEY_BUILD                | Build number of LabKey version to install                         | 2                                                                                                                                                                                                              | yes      |
| LABKEY_DISTRIBUTION         | Name of LabKey distribution to install                            | community                                                                                                                                                                                                      | yes      |
| LABKEY_DIST_BUCKET          | Bucket name where distributions are located                       | lk-binaries                                                                                                                                                                                                    | no       |
| LABKEY_DIST_REGION          | Region the LABKEY_DIST_BUCKET resides in                          | us-west-2                                                                                                                                                                                                      | no       |
| LABKEY_DIST_URL             | URL for downloading distribution files                            | https://${LABKEY_DIST_BUCKET}.s3.${LABKEY_DIST_REGION}.amazonaws.com/downloads/release/${LABKEY_DISTRIBUTION}/${LABKEY_VERSION}/LabKey${LABKEY_VERSION}-${LABKEY_BUILD}-${LABKEY_DISTRIBUTION}-embedded.tar.gz | no       |
| LABKEY_DIST_FILENAME        | Filename of distribution                                          | LabKey${LABKEY_VERSION}-${LABKEY_BUILD}-${LABKEY_DISTRIBUTION}-embedded.tar.gz                                                                                                                                 | no       |
| LABKEY_DIST_DIR             | Name of distribution directory (removes embedded from file name)  | ${LABKEY_DIST_FILENAME::-16}                                                                                                                                                                                   | no       |
| LABKEY_HTTP_PORT            | TCP Port for tomcat/LabKey application                            | 8080                                                                                                                                                                                                           | no       |
| LABKEY_HTTPS_PORT           | TCP Port for tomcat/LabKey application                            | 8443                                                                                                                                                                                                           | no       |
| LABKEY_LOG_DIR              | Log directory for LabKey application logs                         | ${LABKEY_INSTALL_HOME}/logs                                                                                                                                                                                    | no       |
| LABKEY_CONFIG_DIR           | Config directory for tomcat/LabKey applications                   | ${LABKEY_INSTALL_HOME}/config                                                                                                                                                                                  | no       |
| LABKEY_EXT_MODULES_DIR      | Path to LabKey external modules directory                         | ${LABKEY_EXT_MODULES_DIR:-${LABKEY_INSTALL_HOME}/externalModules}                                                                                                                                              | no       |
| LABKEY_STARTUP_DIR          | Path to LabKey startup directory                                  | ${LABKEY_INSTALL_HOME}/server/startup                                                                                                                                                                          | no       |
| LABKEY_MEK                  | Arbitrary string used in LabKey application to encrypt data       | Randomly generated if none is provided                                                                                                                                                                         | yes      |
| LABKEY_GUID                 | LabKey application GUID used to uniquely identify an installation | Randomly generated if none is providing using `uuidgen`                                                                                                                                                        | no       |

### Both tomcat Install Type Inputs

| Name                         | Description                                                | Default value                                          | Required |
| ---------------------------- | ---------------------------------------------------------- | ------------------------------------------------------ | -------- |
| TOMCAT_INSTALL_TYPE          | Tomcat installation type - "Embedded" or "Standard"        | Embedded                                               | yes      |
| TOMCAT_INSTALL_HOME          | Path to tomcat base installation directory                 | $LABKEY_INSTALL_HOME                                   | yes      |
| TOMCAT_TIMEZONE              | Tomcat timezone                                            | America/Los_Angeles                                    | yes      |
| TOMCAT_TMP_DIR               | Path to tomcat temp directory                              | ${LABKEY_APP_HOME}/tomcat-tmp                          | yes      |
| TOMCAT_LIB_PATH              | Path to tomcat "lib" directory, varies by operating system | /usr/lib64                                             | yes      |
| TOMCAT_USERNAME              | Username used for tomcat application                       | tomcat                                                 | yes      |
| TOMCAT_UID                   | User ID user for tomcat user                               | 3000                                                   | yes      |
| TOMCAT_KEYSTORE_BASE_PATH    | Path to store/access the tomcat TLS keystore files         | $TOMCAT_INSTALL_HOME/SSL                               | yes      |
| TOMCAT_KEYSTORE_FILENAME     | Tomcat keystore filename                                   | keystore.tomcat.p12                                    | yes      |
| TOMCAT_KEYSTORE_ALIAS        | Alias for TLS cert in keystore                             | tomcat                                                 | yes      |
| TOMCAT_KEYSTORE_FORMAT       | tomcat Keystore file format                                | PKCS12                                                 | no       |
| TOMCAT_KEYSTORE_PASSWORD     | Password used for tomcat keystore                          | Randomly generated if none is provided                 | yes      |
| TOMCAT_SSL_CIPHERS           | Tomcat SSL Ciphers                                         | HIGH:!ADH:!EXP:!SSLv2:!SSLv3:!MEDIUM:!LOW:!NULL:!aNULL | no       |
| TOMCAT_SSL_ENABLED_PROTOCOLS | Tomcat TLS enabled protocols                               | ${TOMCAT_SSL_ENABLED_PROTOCOLS:-TLSv1.3,+TLSv1.2       | no       |
| TOMCAT_SSL_PROTOCOL          | Tomcat SSL Protocol                                        | TLS                                                    | no       |

### Standard tomcat Install Type Inputs

| Name                        | Description                         | Default value                                                                                              | Required |
| --------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------- |
| CATALINA_HOME               | Path used for CATALINA_HOME         | $TOMCAT_INSTALL_HOME                                                                                       | no       |
| TOMCAT_CONTEXT              | Context path for deployment         | ROOT                                                                                                       | no       |
| TOMCAT_VERSION              | Tomcat version to install           | 9.0.50                                                                                                     | Yes      |
| TOMCAT_URL                  | URL to download tomcat distribution | <http://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz> | yes      |
| TOMCAT_USE_PRIVILEGED_PORTS | Use TCP ports < 1024 e.g. 80/443    | FALSE                                                                                                      | no       |        

### Embedded tomcat Install Type Inputs

| Name                 | Description                                             | Default value                                                                                                                                                                                                            | Required |
| -------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| LABKEY_INSTALLER_CMD | LabKey installer command for non-embedded installations | $LABKEY_SRC_HOME/${LABKEY_DIST_FILENAME::-7}/manual-upgrade.sh -l $LABKEY_INSTALL_HOME/ -d $LABKEY_SRC_HOME/${LABKEY_DIST_FILENAME::-7} -c $TOMCAT_INSTALL_HOME -u $TOMCAT_USERNAME --noPrompt --tomcat_lk --skip_tomcat | yes      |

### Tomcat TLS Certificates Inputs

| Name    | Description         | Default value          | Required |
| ------- | ------------------- | ---------------------- | -------- |
| CERT_C  | Country             | US                     | yes      |
| CERT_ST | State               | Washington             | yes      |
| CERT_L  | Locality or City    | Seattle                | yes      |
| CERT_O  | Organization Name   | ${LABKEY_COMPANY_NAME} | yes      |
| CERT_OU | Organizational Unit | IT                     | yes      |
| CERT_CN | FQDN                | localhost              | yes      |

### Tomcat properties used in application.properties for embedded installations

| Name                 | Description                | Default value | Required |
| -------------------- | -------------------------- | ------------- | -------- |
| LOG_LEVEL_TOMCAT     | Tomcat log-level           | OFF           | no       |
| LOG_LEVEL_SPRING_WEB | Spring framework log-level | OFF           | no       |
| LOG_LEVEL_SQL        | SQL log-level              | OFF           | no       |

### Postgres Inputs

| Name                | Description                                                                 | Default value                          | Required |
| ------------------- | --------------------------------------------------------------------------- | -------------------------------------- | -------- |
| POSTGRES_HOST       | Postgres FQDN url                                                           | localhost                              | yes      |
| POSTGRES_DB         | Postgres database name                                                      | labkey                                 | yes      |
| POSTGRES_USER       | Postgres user's username                                                    | labkey                                 | yes      |
| POSTGRES_SVR_LOCAL  | Flag to trigger install/config of local postgres server - "TRUE" or "FALSE" | FALSE                                  | yes      |
| POSTGRES_PORT       | Postgres TCP Port                                                           | 5432                                   | yes      |
| POSTGRES_PARAMETERS | Additional postgres parameters                                              | NULL                                   | no       |
| POSTGRES_PASSWORD   | Postgres user's password                                                    | Randomly generated if none is provided | yes      |

### SMTP Inputs

| Name          | Description                                    | Default value | Required |
| ------------- | ---------------------------------------------- | ------------- | -------- |
| SMTP_HOST     | SMTP Hostname                                  | localhost     | no       |
| SMTP_USER     | SMTP Username for authenticated SMTP send      | NULL          | no       |
| SMTP_PORT     | SMTP Port                                      | NULL          | no       |
| SMTP_PASSWORD | SMTP user password for authenticated SMTP send | NULL          | no       |
| SMTP_AUTH     |                                                | NULL          | no       |
| SMTP_FROM     |                                                | NULL          | no       |
| SMTP_STARTTLS | Use STARTTLS for sending SMTP                  | TRUE          | no       |

### ALT File Root Inputs

| Name                      | Description                                                   | Default           | Required |
| ------------------------- | ------------------------------------------------------------- | ----------------- | -------- |
| ALT_FILE_ROOT_HEAD        | Default file root path                                        | /media/ebs_volume | no       |
| COOKIE_ALT_FILE_ROOT_HEAD | Cookie file to designate if the ebs volume has been formatted | .ebs_volume       | no       |

### WCP Inputs

Applies only to `install-wcp.bash`

| Name                      | Description                                                                                                                          | Default value                                                                                                | Required |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ | -------- |
| LABKEY_INSTALL_SCRIPT_URL | URL to the install-labkey.bash install script - the wcp install script depends on this for common functions                          | NULL                                                                                                         | yes      |
| WCP_APP_ENV               | WCP environment type - "dev" or "uat" or "prod"                                                                                      | uat                                                                                                          | yes      |
| WCP_CONTACT_EMAIL         | Default "contact us" email address                                                                                                   | donotreply@domain.com                                                                                        | yes      |
| WCP_FEEDBACK_EMAIL        | Default feedback email address                                                                                                       | donotreply@domain.com                                                                                        | yes      |
| WCP_FROM_EMAIL            | Default "from" email address                                                                                                         | donotreply@domain.com                                                                                        | yes      |
| WCP_ADMIN_FIRSTNAME       | Initial administrator first Name                                                                                                     | WCP                                                                                                          | yes      |
| WCP_ADMIN_EMAIL           | Initial administrator email address - set to a mailbox you control and use forgot password link to set password for first time login | donotreply@domain.com                                                                                        | yes      |
| WCP_ADMIN_LASTNAME        | Initial administrator last Name                                                                                                      | Administrator                                                                                                | yes      |
| WCP_HOSTNAME              | FQDN hostname                                                                                                                        | localhost:8443                                                                                               | yes      |
| WCP_PRIVACY_POLICY_URL    | External url for privacy policy                                                                                                      | NULL                                                                                                         | yes      |
| WCP_REGISTRATION_URL      | Registration server URL                                                                                                              | NULL                                                                                                         | yes      |
| WCP_TERMS_URL             | External link to terms and conditions URL                                                                                            | NULL                                                                                                         | yes      |
| WCP_DIST_URL              | URL to download WCP installer distributions                                                                                          | <https://github.com/FDA-MyStudies/WCP/releases/download/21.3.8/wcp_full-21.3.8-5.zip>                        | yes      |
| WCP_DIST_FILENAME         | Filename of WCP distribution                                                                                                         | wcp_full-21.3.8-5.zip                                                                                        | yes      |
| WCP_SQL_SCRIPT_URL        | URL for SQL Script used to initialize system for the initial installation                                                            | <https://raw.githubusercontent.com/FDA-MyStudies/WCP/develop/sqlscript/HPHC_My_Studies_DB_Create_Script.sql> | yes      |
| WCP_SQL_FILENAME          | Filename to store the sql script locally for installation                                                                            | My_Studies_DB_Create_Script.sql                                                                              | yes      |
| MYSQL_HOST                | FQDN of MySQL DB Host                                                                                                                | localhost                                                                                                    | yes      |
| MYSQL_DB                  | MySQL Database name                                                                                                                  | wcp_db                                                                                                       | yes      |
| MYSQL_USER                | MySQL user's username                                                                                                                | app                                                                                                          | yes      |
| MYSQL_SVR_LOCAL           | Flag to trigger install/config of local MySQL server - "TRUE" or "FALSE"                                                             | FALSE                                                                                                        | yes      |
| MYSQL_PORT                | MySQL TCP port                                                                                                                       | 3306                                                                                                         | yes      |
| MYSQL_PASSWORD            | MySQL user's password (must meet complexity standards)                                                                               | NULL                                                                                                         | yes      |
| MYSQL_ROOT_PASSWORD       | MySQL "root" user's password (must meet complexity standards)                                                                        | NULL                                                                                                         | yes      |

## Reference

- [Spring `application.properties`](https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html)
- [`shunit2` assertions](https://github.com/kward/shunit2#asserts)
- [bash "strict mode"](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [`sh-checker` Github Action](https://github.com/luizm/action-sh-checker)
- [`shellcheck` codes](https://gist.github.com/eggplants/9fbe03453c3f3fd03295e88def6a1324#file-_shellcheck-md)
- [`shfmt` flags](https://github.com/mvdan/sh/blob/master/cmd/shfmt/shfmt.1.scd#printer-flags)
