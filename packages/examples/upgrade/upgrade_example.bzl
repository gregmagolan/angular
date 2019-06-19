load("//packages/bazel:index.bzl", "protractor_web_test_suite")
load("//tools:defaults.bzl", "ng_module", "ts_library")
load("@npm_bazel_typescript//:index.bzl", "ts_devserver")

"""
  Macro that can be used to create the Bazel targets for an "upgrade" example. Since the
  upgrade examples bootstrap their application manually, and we cannot serve all examples,
  we need to define the devserver for each example. This macro reduces code duplication
  for defining these targets.
"""

def create_upgrade_example_targets(name, srcs, e2e_srcs, entry_module, assets = []):
    ng_module(
        name = "%s_sources" % name,
        srcs = srcs,
        # TODO: FW-1004 Type checking is currently not complete.
        type_check = False,
        deps = [
            "@npm//@types/angular",
            "@npm//@types/jasmine",
            "//packages/core",
            "//packages/platform-browser",
            "//packages/platform-browser-dynamic",
            "//packages/upgrade/static",
            "//packages/core/testing",
            "//packages/upgrade/static/testing",
        ],
        tsconfig = "//packages/examples/upgrade:tsconfig-build.json",
    )

    ts_library(
        name = "%s_e2e_lib" % name,
        srcs = e2e_srcs,
        testonly = True,
        deps = [
            "@npm//@types/jasminewd2",
            "@npm//protractor",
            "//packages/examples/test-utils",
            "//packages/private/testing",
        ],
        tsconfig = "//packages/examples:tsconfig-e2e.json",
    )

    ts_devserver(
        name = "devserver",
        port = 4200,
        entry_module = entry_module,
        static_files = [
            "@npm//:node_modules/zone.js/dist/zone.js",
            "@npm//:node_modules/angular/angular.js",
            "@npm//:node_modules/reflect-metadata/Reflect.js",
        ],
        index_html = "//packages/examples:index.html",
        scripts = [
            "@npm//:node_modules/tslib/tslib.js",
            "//tools/rxjs:rxjs_umd_modules",
        ],
        deps = [":%s_sources" % name],
        data = assets,
    )

    protractor_web_test_suite(
        name = "%s_protractor" % name,
        data = ["//packages/bazel/src/protractor/utils"],
        on_prepare = "//packages/examples/upgrade:start-server.js",
        server = ":devserver",
        deps = [
            ":%s_e2e_lib" % name,
            "@npm//protractor",
            "@npm//selenium-webdriver",
        ],
    )
