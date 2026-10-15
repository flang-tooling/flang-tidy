# -*- Python -*-
#
# Standalone lit configuration. Needs no generated lit.site.cfg.py: the tool
# locations come from lit --param (or the environment), e.g.
#
#   lit -v test/ --param flang_tidy_dir=$PWD/build \
#                --param llvm_tools_dir=/usr/lib/llvm-23/bin

import os
import shlex
import sys

import lit.formats

config.name = "flang-tidy"
config.test_format = lit.formats.ShTest()
config.suffixes = [".f", ".f90", ".f95", ".f03", ".f08", ".mod", ".test"]
config.excludes = ["Inputs"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = config.test_source_root


def tool_dir(param, env):
    return lit_config.params.get(param, os.environ.get(env, ""))


# check_flang_tidy.py invokes flang-tidy, FileCheck and not by bare name.
path = [
    tool_dir("flang_tidy_dir", "FLANG_TIDY_DIR"),
    tool_dir("llvm_tools_dir", "LLVM_TOOLS_DIR"),
]
config.environment["PATH"] = os.pathsep.join(
    [d for d in path if d] + [os.environ.get("PATH", "")]
)
config.environment["FLANG_NO_DEFAULT_CONFIG"] = "1"

config.substitutions.append(
    (
        "%check_flang_tidy",
        "%s %s"
        % (
            shlex.quote(sys.executable),
            shlex.quote(os.path.join(config.test_source_root, "check_flang_tidy.py")),
        ),
    )
)
