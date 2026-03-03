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
This rule generates an Image File System (IFS) for QNX.

In order todo that, the user has to provide a main build file and supporting
files. The main build file will be used as entrypoint and can then include
other build files or perform other operations like packaging any file into the
created IFS.
"""

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:ifs_toolchain_type"
TAR_TOOLCHAIN = "@tar.bzl//tar/toolchain:type"

# todo: Consider to contribute this to "@tar.bzl"
def _untar(ctx, tarball, output_folder):
    tarball_as_list = tarball.files.to_list()
    if len(tarball_as_list) > 1:
        fail("Provided more then one tar-ball for one key.")
    tarball = tarball_as_list[0]
    bsdtar = ctx.toolchains[TAR_TOOLCHAIN]

    args = ctx.actions.args()
    args.add("-x")
    args.add("-C").add(output_folder.path)
    args.add("-f").add(tarball.path)

    ctx.actions.run(
        outputs = [output_folder],
        inputs = [tarball],
        arguments = [args],
        executable = bsdtar.tarinfo.binary,
        toolchain = TAR_TOOLCHAIN,
        mnemonic = "Untar",
        progress_message = "untar %{input}",
    )

def _qnx_ifs_impl(ctx):
    """ Implementation function of qnx_ifs rule.

        This function will merge all .build files into main .build file and
        produce flashable QNX image.
    """
    inputs = []
    extra_build_files = []

    # Choose output filename
    out_name = ctx.attr.out if ctx.attr.out else "{}.{}".format(ctx.attr.name, ctx.attr.extension)
    if "/" in out_name:
        fail("qnx_ifs.out must be a filename without path components, got: {}".format(out_name))

    out_ifs = ctx.actions.declare_file(out_name)

    ifs_tool_info = ctx.toolchains[QNX_FS_TOOLCHAIN].ifs_toolchain_info

    main_build_file = ctx.file.build_file

    inputs.append(main_build_file)
    inputs.extend(ctx.files.srcs)

    args = ctx.actions.args()

    # Add -r roots BEFORE the build file, resolved relative to the main build file’s dir
    for r in ctx.attr.search_roots:
        # Normalize relative to the main build file’s directory
        root_path = main_build_file.dirname + ("/" + r if not r.startswith("/") else r)
        args.add("-r")
        args.add(root_path)

    args.add_all([
        main_build_file.path,
        out_ifs.path,
    ])

    #Add env variables for bazel labels/targets
    env_to_append = {}
    env_to_append = env_to_append | ifs_tool_info.env

    for key, item in ctx.attr.ext_repo_maping.items():
        env_to_append.update({key: ctx.expand_location(item)})

    env_to_append.update({"MAIN_BUILD_FILE_DIR": main_build_file.dirname})

    # Unpack tarballs and add locations as env variables
    for key, tarball in ctx.attr.tars.items():
        unpacked_tarball = ctx.actions.declare_directory("{}_{}".format(ctx.attr.name, key))
        _untar(ctx, tarball, unpacked_tarball)

        env_to_append.update({key: unpacked_tarball.path})
        inputs.append(unpacked_tarball)

    print(env_to_append)

    ctx.actions.run(
        outputs = [out_ifs],
        inputs = inputs,
        arguments = [args],
        executable = ifs_tool_info.executable,
        env = env_to_append,
        tools = ifs_tool_info.tools,
    )

    return [
        DefaultInfo(files = depset([out_ifs])),
    ]

qnx_ifs = rule(
    implementation = _qnx_ifs_impl,
    toolchains = [QNX_FS_TOOLCHAIN, TAR_TOOLCHAIN],
    attrs = {
        "build_file": attr.label(
            allow_single_file = True,
            doc = "Single label that points to the main build file (entrypoint)",
            mandatory = True,
        ),
        "extension": attr.string(
            default = "ifs",
            doc = "Extension for the generated IFS image. Manipulating this extensions is a workaround for IPNext startup code limitation, when interpreting ifs images. This attribute will either disappear or will be replaced by toolchain configuration in order to keep output files consistent.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "List of labels that are used by the `build_file`",
            allow_empty = True,
        ),
        "ext_repo_maping": attr.string_dict(
            allow_empty = True,
            default = {},
            doc = "We are using dict to map env. variables with of external repository",
        ),
        "tars": attr.string_keyed_label_dict(
            allow_files = [".tar"],
            doc = "A map of tar-balls that can be added to the IFS image. The key will be available als variable in the `IFS Build File`, to determine where it should be packaged. e.g. `FOO: '//:my_tar'` can be packaged as /SOME_DIR=${FOO}.",
            allow_empty = True,
        ),
        "out": attr.string(
            default = "",
            doc = "Optional explicit output filename (no path). If empty, uses name + '.' + extension.",
        ),
        "search_roots": attr.string_list(
            default = [],
            doc = "List of paths for mkifs -r, each relative to the main build file's directory (or absolute).",
        ),
    },
)