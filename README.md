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

## Reference

- [Spring `application.properties`](https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html)
- [`shunit2` assertions](https://github.com/kward/shunit2#asserts)
- [bash "strict mode"](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [`sh-checker` Github Action](https://github.com/luizm/action-sh-checker)
- [`shellcheck` codes](https://gist.github.com/eggplants/9fbe03453c3f3fd03295e88def6a1324#file-_shellcheck-md)
- [`shfmt` flags](https://github.com/mvdan/sh/blob/master/cmd/shfmt/shfmt.1.scd#printer-flags)
