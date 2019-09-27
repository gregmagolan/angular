"""Re-export of some bazel rules with repository-wide defaults."""

load("@build_bazel_rules_nodejs//:defs.bzl", "npm_package_bin", _nodejs_binary = "nodejs_binary", _npm_package = "npm_package")
load("@npm_bazel_jasmine//:index.bzl", _jasmine_node_test = "jasmine_node_test")
load("@npm_bazel_karma//:index.bzl", _karma_web_test = "karma_web_test", _karma_web_test_suite = "karma_web_test_suite", _ts_web_test = "ts_web_test", _ts_web_test_suite = "ts_web_test_suite")
load("@npm_bazel_typescript//:index.bzl", _ts_library = "ts_library")
load("//packages/bazel:index.bzl", _ng_module = "ng_module", _ng_package = "ng_package")
load("@npm_bazel_rollup//:index.bzl", _rollup_bundle = "rollup_bundle")
load("@npm_bazel_terser//:index.bzl", "terser_minified")
load("@npm//@babel/cli:index.bzl", "babel")

_DEFAULT_TSCONFIG_TEST = "//packages:tsconfig-test"
_INTERNAL_NG_MODULE_API_EXTRACTOR = "//packages/bazel/src/api-extractor:api_extractor"
_INTERNAL_NG_MODULE_COMPILER = "//packages/bazel/src/ngc-wrapped"
_INTERNAL_NG_MODULE_XI18N = "//packages/bazel/src/ngc-wrapped:xi18n"
_INTERNAL_NG_PACKAGER_PACKAGER = "//packages/bazel/src/ng_package:packager"
_INTERNAL_NG_PACKAGER_DEFALUT_TERSER_CONFIG_FILE = "//packages/bazel/src/ng_package:terser_config.default.json"
_INTERNAL_NG_PACKAGER_DEFAULT_ROLLUP_CONFIG_TMPL = "//packages/bazel/src/ng_package:rollup.config.js"

# Packages which are versioned together on npm
ANGULAR_SCOPED_PACKAGES = ["@angular/%s" % p for p in [
    # core should be the first package because it's the main package in the group
    # this is significant for Angular CLI and "ng update" specifically, @angular/core
    # is considered the identifier of the group by these tools.
    "core",
    "bazel",
    "common",
    "compiler",
    "compiler-cli",
    "animations",
    "elements",
    "platform-browser",
    "platform-browser-dynamic",
    "forms",
    # Current plan for Angular v8 is to not include @angular/http in ng update
    # "http",
    "platform-server",
    "platform-webworker",
    "platform-webworker-dynamic",
    "upgrade",
    "router",
    "language-service",
    "service-worker",
]]

PKG_GROUP_REPLACEMENTS = {
    "\"NG_UPDATE_PACKAGE_GROUP\"": """[
      %s
    ]""" % ",\n      ".join(["\"%s\"" % s for s in ANGULAR_SCOPED_PACKAGES]),
}

def _default_module_name(testonly):
    """ Provide better defaults for package names.

    e.g. rather than angular/packages/core/testing we want @angular/core/testing

    TODO(alexeagle): we ought to supply a default module name for every library in the repo.
    But we short-circuit below in cases that are currently not working.
    """
    pkg = native.package_name()

    if testonly:
        # Some tests currently rely on the long-form package names
        return None

    if pkg.startswith("packages/bazel"):
        # Avoid infinite recursion in the ViewEngine compiler. Error looks like:
        #  Compiling Angular templates (ngc) //packages/bazel/test/ngc-wrapped/empty:empty failed (Exit 1)
        # : RangeError: Maximum call stack size exceeded
        #    at normalizeString (path.js:57:25)
        #    at Object.normalize (path.js:1132:12)
        #    at Object.join (path.js:1167:18)
        #    at resolveModule (execroot/angular/bazel-out/host/bin/packages/bazel/src/ngc-wrapped/ngc-wrapped.runfiles/angular/packages/compiler-cli/src/metadata/bundler.js:582:50)
        #    at MetadataBundler.exportAll (execroot/angular/bazel-out/host/bin/packages/bazel/src/ngc-wrapped/ngc-wrapped.runfiles/angular/packages/compiler-cli/src/metadata/bundler.js:119:42)
        #    at MetadataBundler.exportAll (execroot/angular/bazel-out/host/bin/packages/bazel/src/ngc-wrapped/ngc-wrapped.runfiles/angular/packages/compiler-cli/src/metadata/bundler.js:121:52)
        return None

    if pkg.startswith("packages/"):
        return "@angular/" + pkg[len("packages/"):]

    return None

def ts_library(tsconfig = None, testonly = False, deps = [], module_name = None, **kwargs):
    """Default values for ts_library"""
    deps = deps + ["@npm//tslib"]
    if testonly:
        # Match the types[] in //packages:tsconfig-test.json
        deps.append("@npm//@types/jasmine")
        deps.append("@npm//@types/node")
        deps.append("@npm//@types/events")
    if not tsconfig and testonly:
        tsconfig = _DEFAULT_TSCONFIG_TEST

    if not module_name:
        module_name = _default_module_name(testonly)

    _ts_library(
        tsconfig = tsconfig,
        testonly = testonly,
        deps = deps,
        module_name = module_name,
        **kwargs
    )

def ng_module(name, tsconfig = None, entry_point = None, testonly = False, deps = [], module_name = None, bundle_dts = True, **kwargs):
    """Default values for ng_module"""
    deps = deps + ["@npm//tslib"]
    if testonly:
        # Match the types[] in //packages:tsconfig-test.json
        deps.append("@npm//@types/jasmine")
        deps.append("@npm//@types/node")
        deps.append("@npm//@types/events")
    if not tsconfig and testonly:
        tsconfig = _DEFAULT_TSCONFIG_TEST

    if not module_name:
        module_name = _default_module_name(testonly)
    if not entry_point:
        entry_point = "public_api.ts"
    _ng_module(
        name = name,
        flat_module_out_file = name,
        tsconfig = tsconfig,
        entry_point = entry_point,
        testonly = testonly,
        bundle_dts = bundle_dts,
        deps = deps,
        compiler = _INTERNAL_NG_MODULE_COMPILER,
        api_extractor = _INTERNAL_NG_MODULE_API_EXTRACTOR,
        ng_xi18n = _INTERNAL_NG_MODULE_XI18N,
        module_name = module_name,
        **kwargs
    )

def ng_package(name, readme_md = None, license_banner = None, deps = [], **kwargs):
    """Default values for ng_package"""
    if not readme_md:
        readme_md = "//packages:README.md"
    if not license_banner:
        license_banner = "//packages:license-banner.txt"
    deps = deps + [
        "@npm//tslib",
    ]

    _ng_package(
        name = name,
        deps = deps,
        readme_md = readme_md,
        license_banner = license_banner,
        replacements = PKG_GROUP_REPLACEMENTS,
        ng_packager = _INTERNAL_NG_PACKAGER_PACKAGER,
        terser_config_file = _INTERNAL_NG_PACKAGER_DEFALUT_TERSER_CONFIG_FILE,
        rollup_config_tmpl = _INTERNAL_NG_PACKAGER_DEFAULT_ROLLUP_CONFIG_TMPL,
        **kwargs
    )

def npm_package(name, replacements = {}, **kwargs):
    """Default values for npm_package"""
    _npm_package(
        name = name,
        replacements = dict(replacements, **PKG_GROUP_REPLACEMENTS),
        **kwargs
    )

def ts_web_test(bootstrap = [], deps = [], runtime_deps = [], **kwargs):
    """Default values for ts_web_test"""
    if not bootstrap:
        bootstrap = ["//:web_test_bootstrap_scripts"]
    local_deps = [
        "@npm//:node_modules/tslib/tslib.js",
        "//tools/rxjs:rxjs_umd_modules",
    ] + deps
    local_runtime_deps = [
        "//tools/testing:browser",
    ] + runtime_deps

    _ts_web_test(
        runtime_deps = local_runtime_deps,
        bootstrap = bootstrap,
        deps = local_deps,
        **kwargs
    )

def ts_web_test_suite(bootstrap = [], deps = [], runtime_deps = [], **kwargs):
    """Default values for ts_web_test_suite"""
    if not bootstrap:
        bootstrap = ["//:web_test_bootstrap_scripts"]
    local_deps = [
        "@npm//:node_modules/tslib/tslib.js",
        "//tools/rxjs:rxjs_umd_modules",
    ] + deps
    local_runtime_deps = [
        "//tools/testing:browser",
    ] + runtime_deps

    tags = kwargs.pop("tags", [])

    # rules_webtesting has a required_tag "native" for `chromium-local` browser
    if not "native" in tags:
        tags = tags + ["native"]

    _ts_web_test_suite(
        runtime_deps = local_runtime_deps,
        bootstrap = bootstrap,
        deps = local_deps,
        # Run unit tests on local Chromium by default.
        # You can exclude tests based on tags, e.g. to skip Firefox testing,
        #   `yarn bazel test --test_tag_filters=-browser:firefox-local [targets]`
        browsers = [
            "@io_bazel_rules_webtesting//browsers:chromium-local",
            # Don't test on local Firefox by default, for faster builds.
            # We think that bugs in Angular tend to be caught the same in any
            # evergreen browser.
            # "@io_bazel_rules_webtesting//browsers:firefox-local",
            # TODO(alexeagle): add remote browsers on SauceLabs
        ],
        tags = tags,
        **kwargs
    )

def karma_web_test(bootstrap = [], deps = [], data = [], runtime_deps = [], **kwargs):
    """Default values for karma_web_test"""
    if not bootstrap:
        bootstrap = ["//:web_test_bootstrap_scripts"]
    local_deps = [
        "@npm//karma-browserstack-launcher",
        "@npm//:node_modules/tslib/tslib.js",
        "//tools/rxjs:rxjs_umd_modules",
    ] + deps
    local_runtime_deps = [
        "//tools/testing:browser",
    ] + runtime_deps

    _karma_web_test(
        runtime_deps = local_runtime_deps,
        bootstrap = bootstrap,
        config_file = "//:karma-js.conf.js",
        deps = local_deps,
        data = data + [
            "//:browser-providers.conf.js",
            "//tools:jasmine-seed-generator.js",
        ],
        configuration_env_vars = ["KARMA_WEB_TEST_MODE"],
        **kwargs
    )

def karma_web_test_suite(bootstrap = [], deps = [], **kwargs):
    """Default values for karma_web_test_suite"""
    if not bootstrap:
        bootstrap = ["//:web_test_bootstrap_scripts"]
    local_deps = [
        "@npm//:node_modules/tslib/tslib.js",
        "//tools/rxjs:rxjs_umd_modules",
    ] + deps

    tags = kwargs.pop("tags", [])

    # rules_webtesting has a required_tag "native" for `chromium-local` browser
    if not "native" in tags:
        tags = tags + ["native"]

    _karma_web_test_suite(
        bootstrap = bootstrap,
        deps = local_deps,
        # Run unit tests on local Chromium by default.
        # You can exclude tests based on tags, e.g. to skip Firefox testing,
        #   `yarn bazel test --test_tag_filters=-browser:firefox-local [targets]`
        browsers = [
            "@io_bazel_rules_webtesting//browsers:chromium-local",
            # Don't test on local Firefox by default, for faster builds.
            # We think that bugs in Angular tend to be caught the same in any
            # evergreen browser.
            # "@io_bazel_rules_webtesting//browsers:firefox-local",
            # TODO(alexeagle): add remote browsers on SauceLabs
        ],
        tags = tags,
        **kwargs
    )

def nodejs_binary(data = [], **kwargs):
    """Default values for nodejs_binary"""
    _nodejs_binary(
        # Pass-thru --define=compile=foo as an environment variable
        configuration_env_vars = ["compile"],
        data = data + ["@npm//source-map-support"],
        **kwargs
    )

def jasmine_node_test(deps = [], **kwargs):
    """Default values for jasmine_node_test"""
    deps = deps + [
        # Very common dependencies for tests
        "@npm//chokidar",
        "@npm//domino",
        "@npm//jasmine-core",
        "@npm//reflect-metadata",
        "@npm//source-map-support",
        "@npm//tslib",
        "@npm//xhr2",
    ]
    _jasmine_node_test(
        deps = deps,
        # Pass-thru --define=compile=foo as an environment variable
        configuration_env_vars = ["compile"],
        **kwargs
    )

def ng_rollup_bundle(name, deps = [], **kwargs):
    """Rollup with Build Optimizer

    This provides a variant of the [legacy rollup_bundle] rule that works better for Angular apps.

    Runs [rollup_bundle], [terser_minified], [babel] and [brotli] for downleveling to es5
    to produce a number of output bundles.

    es2015 esm                    : "%{name}.es2015.js"
    es2015 esm minified           : "%{name}.min.es2015.js"
    es2015 esm minified (debug)   : "%{name}.min_debug.es2015.js"
    es5 esm                       : "%{name}.js"
    es5 esm minified              : "%{name}.min.js"
    es5_esm_minified (compressed) : "%{name}.min.js.br",
    es5 esm minified (debug)      : "%{name}.min_debug.js"

    It registers `@angular-devkit/build-optimizer` as a rollup plugin, to get
    better optimization. It also uses ESM5 format inputs, as this is what
    build-optimizer is hard-coded to look for and transform.

    [legacy rollup_bundle]: https://github.com/bazelbuild/rules_nodejs/blob/0.38.3/internal/rollup/rollup_bundle.bzl
    [rollup_bundle]: https://bazelbuild.github.io/rules_nodejs/Rollup.html
    [terser_minified]: https://bazelbuild.github.io/rules_nodejs/Terser.html
    [babel]: https://babeljs.io/
    [brotli]: https://brotli.org/
    """
    deps = deps + [
        "@npm//tslib",
        "@npm//reflect-metadata",
    ]
    _rollup_bundle(
        name = name + ".es2015",
        config_file = "//tools:ng_rollup_bundle.config.js",
        deps = deps,
        **kwargs
    )
    terser_minified(name = name + ".min.es2015", src = name + ".es2015", sourcemap = False)
    native.filegroup(name = name + ".min.es2015.js", srcs = [name + ".min.es2015"])
    terser_minified(name = name + ".min_debug.es2015", src = name + ".es2015", sourcemap = False, debug = True)
    native.filegroup(name = name + ".min_debug.es2015.js", srcs = [name + ".min_debug.es2015"])
    npm_package_bin(
        name = "_%s_brotli" % name,
        tool = "//tools/brotli-cli",
        data = [name + ".min.es2015.js"],
        outs = [name + ".min.es2015.js.br"],
        args = [
            "--output=$(location %s.min.es2015.js.br)" % name,
            "$(location %s.min.es2015.js)" % name,
        ],
    )
    babel(
        name = name,
        outs = [
            name + ".js",
        ],
        args = [
            "$(location :%s.es2015.js)" % name,
            "--no-babelrc",
            "--compact",
            "false",
            "--source-maps",
            "inline",
            "--presets=@babel/preset-env",
            "--out-file",
            "$(location :%s.js)" % name,
        ],
        data = [
            name + ".es2015.js",
            "@npm//@babel/preset-env",
        ],
    )
    terser_minified(name = name + ".min", src = name + "", sourcemap = False)
    native.filegroup(name = name + ".min.js", srcs = [name + ".min"])
    terser_minified(name = name + ".min_debug", src = name + "", sourcemap = False, debug = True)
    native.filegroup(name = name + ".min_debug.js", srcs = [name + ".min_debug"])
    npm_package_bin(
        name = "_%s_es5_brotli" % name,
        tool = "//tools/brotli-cli",
        data = [name + ".min.js"],
        outs = [name + ".min.js.br"],
        args = [
            "--output=$(location %s.min.js.br)" % name,
            "$(location %s.min.js)" % name,
        ],
    )

def rollup_bundle(name, testonly = False, **kwargs):
    """A drop in replacement for the rules nodejs [legacy rollup_bundle].

    Runs [rollup_bundle], [terser_minified] and [babel] for downleveling to es5
    to produce a number of output bundles.

    es2015 esm                  : "%{name}.es2015.js"
    es2015 esm minified         : "%{name}.min.es2015.js"
    es2015 esm minified (debug) : "%{name}.min_debug.es2015.js"
    es5 esm                     : "%{name}.js"
    es5 esm minified            : "%{name}.min.js"
    es5 esm minified (debug)    : "%{name}.min_debug.js"
    es5 umd                     : "%{name}.es5umd.js"
    es5 umd minified            : "%{name}.min.es5umd.js"
    es2015 umd                  : "%{name}.umd.js"
    es2015 umd minified         : "%{name}.min.umd.js"

    [legacy rollup_bundle]: https://github.com/bazelbuild/rules_nodejs/blob/0.38.3/internal/rollup/rollup_bundle.bzl
    [rollup_bundle]: https://bazelbuild.github.io/rules_nodejs/Rollup.html
    [terser_minified]: https://bazelbuild.github.io/rules_nodejs/Terser.html
    [babel]: https://babeljs.io/
    """

    # esm
    _rollup_bundle(name = name + ".es2015", testonly = testonly, **kwargs)
    terser_minified(name = name + ".min.es2015", testonly = testonly, src = name + ".es2015", sourcemap = False)
    native.filegroup(name = name + ".min.es2015.js", testonly = testonly, srcs = [name + ".min.es2015"])
    terser_minified(name = name + ".min_debug.es2015", testonly = testonly, src = name + ".es2015", sourcemap = False, debug = True)
    native.filegroup(name = name + ".min_debug.es2015.js", testonly = testonly, srcs = [name + ".min_debug.es2015"])
    babel(
        name = name + "",
        testonly = testonly,
        outs = [
            name + ".js",
        ],
        args = [
            "$(location :%s.es2015.js)" % name,
            "--no-babelrc",
            "--compact",
            "false",
            "--source-maps",
            "inline",
            "--presets=@babel/preset-env",
            "--out-file",
            "$(location :%s.js)" % name,
        ],
        data = [
            name + ".es2015.js",
            "@npm//@babel/preset-env",
        ],
    )
    terser_minified(name = name + ".min", testonly = testonly, src = name + "", sourcemap = False)
    native.filegroup(name = name + ".min.js", testonly = testonly, srcs = [name + ".min"])
    terser_minified(name = name + ".min_debug", testonly = testonly, src = name + "", sourcemap = False, debug = True)
    native.filegroup(name = name + ".min_debug.js", testonly = testonly, srcs = [name + ".min_debug"])

    # umd
    _rollup_bundle(name = name + ".umd", testonly = testonly, format = "umd", **kwargs)
    terser_minified(name = name + ".min.umd", testonly = testonly, src = name + ".umd", sourcemap = False)
    native.filegroup(name = name + ".min.umd.js", testonly = testonly, srcs = [name + ".min.umd"])
    babel(
        name = name + ".es5umd",
        testonly = testonly,
        outs = [
            name + ".es5umd.js",
        ],
        args = [
            "$(location :%s.umd.js)" % name,
            "--no-babelrc",
            "--compact",
            "false",
            "--source-maps",
            "inline",
            "--presets=@babel/preset-env",
            "--out-file",
            "$(location :%s.es5umd.js)" % name,
        ],
        data = [
            name + ".umd.js",
            "@npm//@babel/preset-env",
        ],
    )
    terser_minified(name = name + ".min.es5umd", testonly = testonly, src = name + ".es5umd", sourcemap = False)
    native.filegroup(name = name + ".min.es5umd.js", testonly = testonly, srcs = [name + ".min.es5umd"])
