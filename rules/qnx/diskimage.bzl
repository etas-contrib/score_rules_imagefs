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

"""
This rule generates a disk image for QNX using the diskimage utility.

The user provides a main build file that describes the disk layout (partitions,
filesystems, etc.). The diskimage tool creates a composite disk image from this
specification.
"""

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:diskimage_toolchain_type"

def _diskimage_impl(ctx):
    """ Implementation function of diskimage rule.

        This function uses the QNX diskimage utility to create a composite
        disk image from the provided build file specification.
    """
    inputs = []

    # Choose output filename
    out_name = ctx.attr.out if ctx.attr.out else "{}.{}".format(ctx.attr.name, ctx.attr.extension)
    if "/" in out_name:
        fail("diskimage.out must be a filename without path components, got: {}".format(out_name))

    out_img = ctx.actions.declare_file(out_name)

    diskimage_tool_info = ctx.toolchains[QNX_FS_TOOLCHAIN].ifs_toolchain_info

    main_build_file = ctx.file.build_file

    inputs.append(main_build_file)
    inputs.extend(ctx.files.srcs)

    args = ctx.actions.args()

    if ctx.attr.gpt_enabled:
        args.add("-g")

    args.add_all([
        "-o",
        out_img.path,
        "-c",
        main_build_file.path,
    ])

    #Add env variables for bazel labels/targets
    env_to_append = {}
    env_to_append = env_to_append | diskimage_tool_info.env

    ctx.actions.run(
        outputs = [out_img],
        inputs = inputs,
        arguments = [args],
        executable = diskimage_tool_info.executable,
        env = env_to_append,
        tools = diskimage_tool_info.tools,
    )

    return [
        DefaultInfo(files = depset([out_img])),
    ]

diskimage = rule(
    implementation = _diskimage_impl,
    toolchains = [QNX_FS_TOOLCHAIN],
    attrs = {
        "build_file": attr.label(
            allow_single_file = True,
            doc = "Single label that points to the main build file (disk layout specification)",
            mandatory = True,
        ),
        "extension": attr.string(
            default = "img",
            doc = "Extension for the generated disk image.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "List of labels that are used by the `build_file`",
            allow_empty = True,
        ),
        "out": attr.string(
            default = "",
            doc = "Optional explicit output filename (no path). If empty, uses name + '.' + extension.",
        ),
        "gpt_enabled": attr.bool(
            default = False,
            doc = "When True, passes -g to diskimage to generate a GPT (GUID Partition Table) disk image.",
        ),
    },
)
