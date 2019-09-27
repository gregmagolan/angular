"""Custom rollup_bundle for language service.

Overrides format to AMD and produces only umd and min, no FESM.

We do this so that we bundle all of the dependencies into the bundle
except for typescript, fs and path.

This allows editors and other tools to easily use the language service bundle
without having to provide all of the angular specific peer dependencies.
"""

load("@build_bazel_rules_nodejs//:providers.bzl", "NpmPackageInfo")
load(
    "//packages/bazel/src/ng_package:ng_package.bzl",
    "NG_PACKAGE_DEPS_ASPECTS",
    "write_rollup_config",
)
load("//packages/bazel/src:esm5.bzl", "esm5_root_dir", "flatten_esm5")

_DEFAULT_ROLLUP_CONFIG_TMPL = "//packages/bazel/src/ng_package:rollup.config.js"
_DEFAULT_ROLLUP = "@npm//rollup/bin:rollup"

# Note: the file is called "umd.js" and "umd.min.js" because of historical
# reasons. The format is actually amd and not umd, but we are afraid to rename
# the file because that would likely break the IDE and other integrations that
# have the path hardcoded in them.
_LS_ROLLUP_OUTPUTS = {
    "build_umd": "%{name}.umd.js",
    # min bundle is not used at the moment. Disable to speed up build
    # "build_umd_min": "%{name}.umd.min.js",
}

_LS_ROLLUP_ATTRS = {
    "srcs": attr.label_list(
        doc = """JavaScript source files from the workspace.
        These can use ES2015 syntax and ES Modules (import/export)""",
        allow_files = True,
    ),
    "entry_point": attr.label(
        doc = """The starting point of the application, passed as the `--input` flag to rollup.

        If the entry JavaScript file belongs to the same package (as the BUILD file), 
        you can simply reference it by its relative name to the package directory:

        ```
        ls_rollup_bundle(
            name = "bundle",
            entry_point = ":main.js",
        )
        ```

        You can specify the entry point as a typescript file so long as you also include
        the ts_library target in deps:

        ```
        ts_library(
            name = "main",
            srcs = ["main.ts"],
        )

        ls_rollup_bundle(
            name = "bundle",
            deps = [":main"]
            entry_point = ":main.ts",
        )
        ```

        The rule will use the corresponding `.js` output of the ts_library rule as the entry point.

        If the entry point target is a rule, it should produce a single JavaScript entry file that will be passed to the nodejs_binary rule. 
        For example:

        ```
        filegroup(
            name = "entry_file",
            srcs = ["main.js"],
        )

        ls_rollup_bundle(
            name = "bundle",
            entry_point = ":entry_file",
        )
        ```
        """,
        mandatory = True,
        allow_single_file = True,
    ),
    "global_name": attr.string(
        doc = """A name given to this package when referenced as a global variable.
        This name appears in the bundle module incantation at the beginning of the file,
        and governs the global symbol added to the global context (e.g. `window`) as a side-
        effect of loading the UMD/IIFE JS bundle.

        Rollup doc: "The variable name, representing your iife/umd bundle, by which other scripts on the same page can access it."

        This is passed to the `output.name` setting in Rollup.""",
    ),
    "globals": attr.string_dict(
        doc = """A dict of symbols that reference external scripts.
        The keys are variable names that appear in the program,
        and the values are the symbol to reference at runtime in a global context (UMD bundles).
        For example, a program referencing @angular/core should use ng.core
        as the global reference, so Angular users should include the mapping
        `"@angular/core":"ng.core"` in the globals.""",
        default = {},
    ),
    "license_banner": attr.label(
        doc = """A .txt file passed to the `banner` config option of rollup.
        The contents of the file will be copied to the top of the resulting bundles.
        Note that you can replace a version placeholder in the license file, by using
        the special version `0.0.0-PLACEHOLDER`. See the section on stamping in the README.""",
        allow_single_file = [".txt"],
    ),
    "deps": attr.label_list(
        doc = """Other rules that produce JavaScript outputs, such as `ts_library`.""",
        aspects = NG_PACKAGE_DEPS_ASPECTS,
    ),
    "rollup": attr.label(
        default = Label(_DEFAULT_ROLLUP),
        executable = True,
        cfg = "host",
    ),
    "rollup_config_tmpl": attr.label(
        default = Label(_DEFAULT_ROLLUP_CONFIG_TMPL),
        allow_single_file = True,
    ),
}

def _filter_js_inputs(all_inputs):
    # Note: make sure that "all_inputs" is not a depset.
    # Iterating over a depset is deprecated!
    return [
        f
        for f in all_inputs
        # We also need to include ".map" files as these can be read by
        # the "rollup-plugin-sourcemaps" plugin.
        if f.path.endswith(".js") or f.path.endswith(".json") or f.path.endswith(".map")
    ]

def _run_rollup(ctx, sources, config, output):
    """Creates an Action that can run rollup on set of sources.

    This is also used by ng_package and ng_rollup_bundle rules in @angular/bazel.

    Args:
      ctx: Bazel rule execution context
      sources: JS sources to rollup
      config: rollup config file
      output: output file

    Returns:
      the sourcemap output file
    """
    map_output = ctx.actions.declare_file(output.basename + ".map", sibling = output)

    args = ctx.actions.args()
    args.add_all(["--config", config.path])
    args.add_all(["--output.file", output.path])
    args.add_all(["--output.sourcemap", "--output.sourcemapFile", map_output.path])

    # We will produce errors as needed. Anything else is spammy: a well-behaved
    # bazel rule prints nothing on success.
    args.add("--silent")

    if ctx.attr.globals:
        args.add("--external")
        args.add_joined(ctx.attr.globals.keys(), join_with = ",")
        args.add("--globals")
        args.add_joined(["%s:%s" % g for g in ctx.attr.globals.items()], join_with = ",")

    direct_inputs = [config]
    if hasattr(ctx.attr, "node_modules"):
        direct_inputs += _filter_js_inputs(ctx.files.node_modules)

    # Also include files from npm fine grained deps as inputs.
    # These deps are identified by the NpmPackageInfo provider.
    for d in ctx.attr.deps:
        if NpmPackageInfo in d:
            # Note: we can't avoid calling .to_list() on sources
            direct_inputs += _filter_js_inputs(d[NpmPackageInfo].sources.to_list())

    if ctx.file.license_banner:
        direct_inputs += [ctx.file.license_banner]
    if ctx.version_file:
        direct_inputs += [ctx.version_file]

    ctx.actions.run(
        progress_message = "Bundling JavaScript %s [rollup]" % output.short_path,
        executable = ctx.executable.rollup,
        inputs = depset(direct_inputs, transitive = [sources]),
        outputs = [output, map_output],
        arguments = [args],
    )

    return map_output

def _ls_rollup_bundle(ctx):
    esm5_sources = flatten_esm5(ctx)
    rollup_config = write_rollup_config(
        ctx,
        root_dir = "/".join([ctx.bin_dir.path, ctx.label.package, esm5_root_dir(ctx)]),
        output_format = "amd",
    )
    _run_rollup(ctx, esm5_sources, rollup_config, ctx.outputs.build_umd)

    # source_map = run_terser(ctx, ctx.outputs.build_umd, ctx.outputs.build_umd_min)
    return DefaultInfo(
        files = depset([
            ctx.outputs.build_umd,
            # ctx.outputs.build_umd_min,
            # source_map,
        ]),
    )

ls_rollup_bundle = rule(
    implementation = _ls_rollup_bundle,
    attrs = _LS_ROLLUP_ATTRS,
    outputs = _LS_ROLLUP_OUTPUTS,
)
