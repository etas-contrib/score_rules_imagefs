# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************

""" Module extension for setting up Image File System toolchains in Bazel.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@score_rules_imagefs//rules/qnx:imagefs_toolchain.bzl", "imagefs_toolchain")

# IFS interface API for archive tag class
_attrs_sdp = {
    "name": attr.string(
        default = "",
        doc = "package name of toolchain, default set to toolchain toolchain name + `_pkg`.",
    ),
    "build_file": attr.string(
        mandatory = False,
        default = "",
        doc = "The path to the BUILD file of selected archive.",
    ),
    "url": attr.string(
        mandatory = False,
        default = "",
        doc = "Url to the toolchain archive."
    ),
    "strip_prefix": attr.string(
        mandatory = False,
        default = "",
        doc = "Strip prefix from toolchain archive.", 
    ),
    "sha256": attr.string(
        mandatory = False,
        default = "",
        doc = "Checksum of the archive."
    ),
}

# GCC interface API for toolchain tag class
_attrs_tc = {
    "name": attr.string(
        mandatory = True,
        doc = "Toolchain repo name, default set to `score_gcc_toolchain`.",
    ),
    "sdp_to_import": attr.label(
        mandatory = False,
        default = None, 
        doc = "The label of SDP package to import from different extension( e.g. from `gcc`) ",
    ),
    "target_cpu": attr.string(
        mandatory = True,
        values = [
            "x86_64",
            "aarch64",
        ],
        doc = "Target platform CPU",
    ),
    "target_os": attr.string(
        mandatory = True,
        values = [
            "linux",
            "qnx",
        ],
        doc = "Target platform OS",
    ),
    "sdp_version": attr.string(
        default = "8.0.0",
        mandatory = False,
        doc = "Version of the SDP package.",
    ),
    "type": attr.string(
        values = [
            "ifs",
            "qnx6fs",
        ],
        mandatory = True,
        doc = "Image FileSystem type: ifs or qnx6fs",
    ),
    "license_path": attr.string(
        default = "/opt/score_qnx/license/licenses",
        mandatory = False,
        doc = "Path to the shared license file.",
    ),
    "license_info_url": attr.string(
        default = "",
        mandatory = False,
        doc = "URL of the QNX license server.",
    ),
    "license_info_variable": attr.string(
        default = "",
        mandatory = False,
        doc = "QNX License info variable.",
    ),
}

def _get_packages(tags):
    """Gets archive information from given tags.

    Args:
        tags: A list of tags containing archive information.

    Returns:
        dict: A dictionary with archive information.
    """
    packages = []
    for tag in tags:
        packages.append({
            "build_file": tag.build_file,
            "name": tag.name,
            "sha256": tag.sha256,
            "strip_prefix": tag.strip_prefix,
            "url": tag.url,
        })
    return packages


def _get_toolchains(tags):
    """Gets toolchain information from given tags.

    Args:
        tags: A list of tags containing toolchain information.
    
    Returns:
        dict: A dictionary with toolchain information.
    """
    toolchains = []
    for tag in tags:
        toolchain = {
            "name": tag.name,
            "tc_cpu": tag.target_cpu,
            "tc_os": tag.target_os,
            "sdp_to_import": "@@{}".format(tag.sdp_to_import.repo_name) if tag.sdp_to_import != None else "",
            "sdp_version": tag.sdp_version,
            "tc_license_info_variable": tag.license_info_variable,
            "tc_license_info_url": tag.license_info_url,
            "tc_license_path": tag.license_path,
            "tc_type": tag.type,
        }
        toolchains.append(toolchain)
    return toolchains

def _get_info(mctx):
    root = None
    for mod in mctx.modules:
        if not mod.is_root:
            fail("Only the root module can use the 'imagefs' extension!")
        root = mod

    toolchains = _get_toolchains(mod.tags.toolchain)
    for tc in toolchains:
        if tc["tc_type"] == "qnx6fs":
            fail("The `qnx6fs` type is not yet supported! Exiting . . .")
    packages = _get_packages(root.tags.sdp)

    return toolchains, packages

def _impl(mctx):
    """Extracts information about toolchain and instantiates nessesary rules for toolchain declaration.

    Args:
       mctx: A bazel object holding module information.

    """

    toolchains, archives = _get_info(mctx)
    for archive_info in archives:
        http_archive(
            name = archive_info["name"],
            urls = [archive_info["url"]],
            build_file = archive_info["build_file"],
            sha256 = archive_info["sha256"],
            strip_prefix = archive_info["strip_prefix"],
        )

    for toolchain_info in toolchains:
        imagefs_toolchain(
            name = toolchain_info["name"],
            tc_cpu = toolchain_info["tc_cpu"],
            tc_os = toolchain_info["tc_os"],
            tc_pkg_repo = toolchain_info["sdp_to_import"],
            sdp_version = toolchain_info["sdp_version"],
            tc_type = toolchain_info["tc_type"],
        )

imagefs = module_extension(
    implementation = _impl,
    tag_classes = {
        "toolchain": tag_class(
            attrs = _attrs_tc,
            doc = "Toolchain configuration parameters that define toolchain."
        ),
        "sdp": tag_class(
            attrs = _attrs_sdp,
            doc = "Software Development Package (short sdp) is tarball holding binaries of toolchain.",
        ),
    }
)