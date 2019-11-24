# Copyright Google Inc. All Rights Reserved.
#
# Use of this source code is governed by an MIT-style license that can be
# found in the LICENSE file at https://angular.io/license
"""Function to generate pkg_tar definitions for WORKSPACE yarn_install manual_build_file_contents"""

def npm_package_archives():
    npm_packages_to_archive = [
        "typescript",
        "rxjs",
        "tslib",
        "protractor",
        "@angular/cli",
        "@types/node",
    ]
    result = """load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")
"""
    for name in npm_packages_to_archive:
        sanitized_name = name.replace("/", "_").replace("@", "")
        last_segment_name = name if name.find("/") == -1 else name.split("/")[-1]
        result += """pkg_tar(
    name = "{sanitized_name}_archive",
    srcs = ["//{name}:{last_segment_name}__files"],
    extension = "tar.gz",
    strip_prefix = "./node_modules/{name}",
    # should not be build unless it is a dependency of another rule
    tags = ["manual"],
)
""".format(name = name, sanitized_name = sanitized_name, last_segment_name = last_segment_name)
    return result
