# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Angular integration testing
"""

load("//tools/npm_integration_test:npm_integration_test.bzl", "npm_integration_test")

# The @npm packages at the root node_modules are used by integration tests
# with `file:../../node_modules/foobar` references
NPM_PACKAGE_ARCHIVES = [
    "check-side-effects",
    "core-js",
    "jasmine",
    "typescript",
    "rxjs",
    "systemjs",
    "tsickle",
    "tslib",
    "protractor",
    "rollup",
    "rollup-plugin-commonjs",
    "rollup-plugin-node-resolve",
    "@angular/cli",
    "@angular-devkit/build-angular",
    "@types/jasmine",
    "@types/jasminewd2",
    "@types/node",
]

# The generated npm packages should ALWAYS be replaced in integration tests
# so we pass them to the `check_npm_packages` attribute of npm_integration_test
GENERATED_NPM_PACKAGES = [
    "@angular/animations",
    "@angular/bazel",
    "@angular/benchpress",
    "@angular/common",
    "@angular/compiler",
    "@angular/compiler-cli",
    "@angular/core",
    "@angular/elements",
    "@angular/forms",
    "@angular/http",
    "@angular/language-service",
    "@angular/localize",
    "@angular/platform-browser",
    "@angular/platform-browser-dynamic",
    "@angular/platform-server",
    "@angular/platform-webworker",
    "@angular/platform-webworker-dynamic",
    "@angular/router",
    "@angular/service-worker",
    "@angular/upgrade",
    "zone.js",
]

def npm_package_archives():
    """Function to generate pkg_tar definitions for WORKSPACE yarn_install manual_build_file_contents"""
    npm_packages_to_archive = NPM_PACKAGE_ARCHIVES
    result = """load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")
"""
    for name in npm_packages_to_archive:
        label_name = _npm_package_archive_label(name)
        last_segment_name = name if name.find("/") == -1 else name.split("/")[-1]
        result += """pkg_tar(
    name = "{label_name}",
    srcs = ["//{name}:{last_segment_name}__files"],
    extension = "tar.gz",
    strip_prefix = "./node_modules/{name}",
    # should not be build unless it is a dependency of another rule
    tags = ["manual"],
)
""".format(name = name, label_name = label_name, last_segment_name = last_segment_name)
    return result

def _npm_package_archive_label(package_name):
    return package_name.replace("/", "_").replace("@", "") + "_archive"

def _angular_integration_test(freeze_npm_packages = [], **kwargs):
    "Set defaults for the npm_integration_test common to the angular repo"
    commands = kwargs.pop("commands", None)
    if not commands:
        # By default run `yarn install` followed by `yarn test` using
        # the bazel managed hermetic version of yarn inside
        commands = [
            # Workaround https://github.com/yarnpkg/yarn/issues/2165
            # Yarn will cache file://dist URIs and not update Angular code
            "mkdir .yarn_local_cache",
            "$(location @nodejs//:yarn_bin) install --cache-folder ./.yarn_local_cache",
            "$(location @nodejs//:yarn_bin) test",
            "rm -rf ./.yarn_local_cache",
        ]

    # Complete of npm packages to override in the test's package.json file mapped to
    # tgz archive to use for the replacement. This is the full list for all integration
    # tests. Any give integration does not need to use all of these packages.
    npm_packages = {}
    for name in NPM_PACKAGE_ARCHIVES:
        if name not in freeze_npm_packages:
            npm_packages["@npm//:" + _npm_package_archive_label(name)] = name
    for name in GENERATED_NPM_PACKAGES:
        last_segment_name = name if name.find("/") == -1 else name.split("/")[-1]
        npm_packages["//packages/%s:npm_package_archive" % last_segment_name] = name

    npm_integration_test(
        check_npm_packages = GENERATED_NPM_PACKAGES,
        commands = commands,
        npm_packages = npm_packages,
        tags = kwargs.pop("tags", []) + [
            # Integration do not work inside of a sandbox as they may run host applications such
            # as chrome (which is run by ng) that require access to files outside of the sandbox.
            # They also need to run locally and not on RBE as they require network access for
            # yarn install & npm install.
            "no-sandbox",
            "local",
        ],
        data = kwargs.pop("data", []) + [
            # We need the yarn_bin & yarn_files available at runtime
            "@nodejs//:yarn_bin",
            "@nodejs//:yarn_files",
        ],
        configuration_env_vars = kwargs.pop("configuration_env_vars", []) + [
            # CI_CHROMEDRIVER_VERSION_ARG is used in post-install to configure
            # which version of chrome driver webdriver-manager downloads. The version
            # specified should work with your local chrome version.
            # --action_env=CI_CHROMEDRIVER_VERSION_ARG is set in .bazelrc so that the
            # test can access this envirnoment variable if it is set. Alternately,
            # if you can set or override the value used by the test with a --define such as
            # --define=CI_CHROMEDRIVER_VERSION_ARG="--versions.chrome 78.0.3904.105"
            "CI_CHROMEDRIVER_VERSION_ARG",
            # CIRCLECI is used by karma & protractor configs to detect if running on CircleCI
            # where they need to run in headless mode when under Bazel
            "CIRCLECI",
        ],
        timeout = "long",
        **kwargs
    )

def angular_integration_test(name, test_folder, freeze_npm_packages = [], **kwargs):
    "Sets up the integration test target based on the test folder name"
    _angular_integration_test(
        name = name,
        test_files = native.glob(
            include = ["%s/**" % test_folder],
            exclude = [
                "%s/node_modules/**" % test_folder,
                "%s/.yarn_local_cache/**" % test_folder,
            ],
        ),
        freeze_npm_packages = freeze_npm_packages,
        **kwargs
    )
