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

""" Toolchain provider implementation for QNX filesystem image rules.
"""

IFSToolchainInfo = provider(
    doc = "Executable for generating QNX filesystems.",
    fields = ["executable", "tools", "env"],
)

def _impl(ctx):
    env = {
        "QNX_HOST": "/proc/self/cwd/" + ctx.file.host_dir.path,
        "QNX_TARGET": "/proc/self/cwd/" + ctx.file.target_dir.path,
        "QNX_CONFIGURATION_EXCLUSIVE": "/var/tmp/.qnx",
        "QNX_SHARED_LICENSE_FILE": "/opt/score_qnx/license/licenses",
        "PATH": "/proc/self/cwd/" + ctx.file.host_dir.path + "/usr/bin",
    }

    return [
        platform_common.ToolchainInfo(
            ifs_toolchain_info = IFSToolchainInfo(
                executable = ctx.executable.executable,
                tools =  depset(ctx.files.host + ctx.files.target, transitive = [ctx.attr.executable.default_runfiles.files]),
                env = env,
            ),
        ),
    ]

ifs_toolchain_config = rule(
    _impl,
    attrs = {
        "executable": attr.label(
            cfg = "exec",
            executable = True,
            mandatory = True,
            doc = "TBD",
        ),
        "host_dir": attr.label(allow_single_file = True, mandatory = True),
        "target_dir": attr.label(allow_single_file = True, mandatory = True),
        "host": attr.label(
            cfg = "exec",
            mandatory = True,
        ),
        "target": attr.label(
            cfg = "exec",
            mandatory = True,
        ),
    },
)