workspace(name = "angular")

# Uncomment for local bazel rules development
#local_repository(
#    name = "build_bazel_rules_nodejs",
#    path = "../rules_nodejs",
#)
#local_repository(
#    name = "build_bazel_rules_typescript",
#    path = "../rules_typescript",
#)

###########################################################
# Download Bazel dependencies directly and from npm

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Explicitly load rules_go
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "b7a62250a3a73277ade0ce306d22f122365b513f5402222403e507f2f997d421",
    url = "https://github.com/bazelbuild/rules_go/releases/download/0.16.3/rules_go-0.16.3.tar.gz",
)

# We build rxjs from source
# TODO(gregmagolan): switch to using rxjs named-UMD bundles on next rxjs release
http_archive(
    name = "rxjs",
    sha256 = "72b0b4e517f43358f554c125e40e39f67688cd2738a8998b4a266981ed32f403",
    strip_prefix = "package/src",
    url = "https://registry.yarnpkg.com/rxjs/-/rxjs-6.3.3.tgz",
)

# The @npm workspace aliases targets to @ngdeps which is setup by yarn_install
# in ng_setup_workspace
local_repository(
    name = "npm",
    path = "tools/npm_workspace",
)

# Install transitive deps of angular rules
load("//packages/bazel:package.bzl", "rules_angular_dependencies", "rules_angular_dev_dependencies")

# Angular Bazel users will call this function
rules_angular_dependencies()

# These are the dependencies only for local development
rules_angular_dev_dependencies()

# Install transitive deps of rules_nodejs
load("@build_bazel_rules_nodejs//:package.bzl", "rules_nodejs_dependencies")

rules_nodejs_dependencies()

# Setup nodejs toolchain
load("@build_bazel_rules_nodejs//:defs.bzl", "check_bazel_version", "node_repositories")

# Bazel version must be at least v0.21.0 because:
#   - 0.21.0 Using --incompatible_strict_action_env flag fixes cache when running `yarn bazel`
#            (see https://github.com/angular/angular/issues/27514#issuecomment-451438271)
check_bazel_version("0.21.0", """
You no longer need to install Bazel on your machine.
Angular has a dependency on the @bazel/bazel package which supplies it.
Try running `yarn bazel` instead.
    (If you did run that, check that you've got a fresh `yarn install`)

""")

node_repositories(
    node_version = "10.9.0",
    package_json = ["//:package.json"],
    yarn_version = "1.12.1",
)

# Call ng_setup_workspace() to install @ngdeps npm dependencies
load("@angular//tools:ng_setup_workspace.bzl", "ng_setup_workspace")

ng_setup_workspace()

# Install all bazel workspaces pulled from npm
load("@ngdeps//:install_workspaces.bzl", "install_workspaces")

install_workspaces()

# Install transitive deps of rules_typescript
load("@build_bazel_rules_typescript//:package.bzl", "rules_typescript_dependencies")

rules_typescript_dependencies()

# Install transitive deps of rules_karma
load("@build_bazel_rules_karma//:package.bzl", "rules_karma_dependencies")

rules_karma_dependencies()

###########################################################
# Setup toolchains for dependencies

# Setup rules_go toolchain
load("@io_bazel_rules_go//go:def.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains()

# Setup rules_webtesting toolchain
load("@io_bazel_rules_webtesting//web:repositories.bzl", "browser_repositories", "web_test_repositories")

web_test_repositories()

browser_repositories(
    chromium = True,
    firefox = True,
)

# Setup rules_typescript toolchain
load("@build_bazel_rules_typescript//:defs.bzl", "ts_setup_workspace")

ts_setup_workspace()

##################################
# Skylark documentation generation

load("@io_bazel_rules_sass//sass:sass_repositories.bzl", "sass_repositories")

sass_repositories()

load("@io_bazel_skydoc//skylark:skylark.bzl", "skydoc_repositories")

skydoc_repositories()
