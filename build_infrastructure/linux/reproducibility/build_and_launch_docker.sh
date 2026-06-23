#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

# The script is to automatically prepare the reproducible code, build docker image and launch the build
# in the docker container.
#
# Usage:
#     ./build_and_launch_docker.sh [ [ -d | --code-dir dir ] [ -t | --reproduce-type type ] | [ -s | --sgx-src-dir src_dir ] [ -h | --help ] ]
#
# Options:
#     -d, --code-dir:
#         Specify the directory you want to download the repo. If this option is
#         not specified, will use the same directory as the script location.
#
#     -t, --reproduce-type:
#         Specify the reproducibility type. Provided options: all|sdk|ipp.
#         Legacy option 'ae' is kept for CLI compatibility and exits with guidance.
#         If one type is provided, the corresponding code will be prepared. And the correponding
#         build steps will also be launched in the container automatically.
#         If no type is provided, all the code will be prepared. And the build steps will
#         be triggered in the container. Then you can choose to build what you want in the container.
#
#    -s, --sgx-src-dir:
#         Specify the local sgx source path if you have pulled the sgx source code via `$git clone`
#         or by other ways.
#         If this option is specified, script will not clone sgx source but start the build based on
#         the code base specified by this option.
#
#     -h, --help:
#         Show this usage message.
#
#

set -e

script_dir="$( cd "$( dirname "$0" )" >> /dev/null 2>&1 && pwd )"
code_dir="$script_dir/code_dir"
sgx_repo="$code_dir/sgx"
type="all"
type_flag=0
mount_dir="/linux-sgx"

sgx_src=""


usage()
{
    echo "
    The script is to automatically prepare the reproducible code, build docker image and launch the build
    in the docker container.

    Usage:
        $0 [ [ -d | --code-dir dir ] [ -t | --reproduce-type type ] | [ -s | --sgx-src-dir src_dir ] [ -h | --help ] ]

    Options:
        -d, --code-dir:
            Specify the directory you want to prepare the code and share to the reproducible container.
            If this option is not specified, will use the same directory as the script location.
        -t, --reproduce-type:
            Specify the reproducibility type. Provided options: all|sdk|ipp.
            Legacy option 'ae' is kept for CLI compatibility and exits with guidance.
            If one type is provided, the corresponding code will be prepared. And the correponding
            build steps will also be executed in the container automatically.
            If no type is provided, all the code will be prepared. And the build steps will not
            be triggered in the container. Then you can choose to build what you want in the container.
        -s, --sgx-src-dir:
            Specify the local sgx source path if you have pulled the sgx source code via \`\$git clone\`
            or by other ways.
            If this option is specified, script will not clone sgx source but start the build based on
            the code base specified by this option.
        -h, --help:
            Show this usage message."
}

parse_cmd()
{
    while [ "$1" != "" ]; do
        case $1 in
            -d | --code-dir ) shift
                code_dir="$1"
                ;;
            -t | --reproduce-type ) shift
                type="$1"
                type_flag=1
                if [ "$type" != "all" ] && [ "$type" != "sdk" ] && [ "$type" != "ae" ] && [ "$type" != "ipp" ]; then
                    usage
                    exit 1
                fi
                ;;
            -h | --help )
                usage
                exit
                ;;
            -s | --sgx-src-dir) shift
                sgx_src="$1"
                if [ ! -d "$sgx_src" ]; then
                    echo "The $sgx_src doesn't exist."
                    usage
                    exit 1
                fi
                sgx_src="$(realpath $sgx_src)"
                ;;
            * )
                usage
                exit 1
        esac
        shift
    done
    mkdir -p "$code_dir" | exit
    code_dir="$(realpath $code_dir)"
    sgx_repo="$code_dir/sgx"
}

prepare_sgx_src()
{
    pushd .
    if [ -d $sgx_repo ]; then
        echo "Removing existing SGX code repo in $sgx_repo"
        rm -rf $sgx_repo
    fi

    # If user prepares the sgx code repo in the host machine, copy the code to $sgx_repo
    # Otherwise, pull the sgx source code.
    if [ "$sgx_src" != "" ]; then
        mkdir -p "$sgx_repo" && cp -a "$sgx_src/." "$sgx_repo"
    else
        git clone -b sgx_2.30 https://github.com/intel/confidential-computing.sgx.sdk.git "$sgx_repo"
    fi

    cd "$sgx_repo" && make preparation
    popd

}

unsupported_ae_message()
{
    echo "ERROR: The SDK installer is no longer supported for this (SGX SDK's) script."
    echo "       Please refer to https://github.com/intel/confidential-computing.sgx/blob/main/linux/installer/bin/build-installpkg.sh for the PSW installer script."
}

generate_cmd_script()
{
    rm -f $code_dir/cmd.sh

    cat > $code_dir/cmd.sh << EOF
#!/usr/bin/env bash

. ~/.bash_profile
nix-shell ~/shell.nix --run "$mount_dir/start_build.sh $type"

EOF

    chmod +x $code_dir/cmd.sh
}

######################################################
# Step 1: Parse command line, prepare code and scripts
######################################################
parse_cmd $@

case $type in
    "all")
        prepare_sgx_src
        ;;
    "sdk")
        prepare_sgx_src
        ;;
    "ae")
        unsupported_ae_message
        exit 1
        ;;
    "ipp")
        prepare_sgx_src
        ;;
    *)
        echo "Unsupported reproducibility type."
        exit 1
esac

cp $script_dir/start_build.sh.tmp $code_dir/start_build.sh
chmod +x $code_dir/start_build.sh
generate_cmd_script

######################################################
# Step 2: Build docker image and launch the container
######################################################
# Check if the image already exists. If not, build the docker image
set +e && docker image inspect sgx.build.env:latest > /dev/null 2>&1 && set -e
if [ $? != 0 ]; then
    docker build -t sgx.build.env --build-arg https_proxy=$https_proxy \
              --build-arg http_proxy=$http_proxy -f $script_dir/Dockerfile .
fi

# WAMR cleanup: `version.h` is an auto-generated file (via CMake's `configure_file()` which is committed to the 3rd party repo and not cleaned up by its `clean` target.
# Deleting it ahead of build, so that subsequent container operations running on the bind-mounted tree, possibly with a different UID, do not encounter permission issues unlinking/replacing this file.
rm -f "${sgx_repo}/external/dcap_source/external/wasm-micro-runtime/core/version.h"

# Allow 'w' permission for other users to the code_dir in case the uid in the container
# is different from the host uid.
chmod -R o+w $code_dir

# Choose whether to allocate a pseudo-TTY for `docker run`.
# - Interactive terminal runs should use `-it` for a good UX.
# - Non-interactive environments (CI, nohup, stdout/stderr redirected to a file, cron)
#   do not have a TTY, and `docker run -t` will fail with:
#     "the input device is not a TTY"
DOCKER_RUN_ARGS=()
if [ -t 0 ] && [ -t 1 ]; then
  DOCKER_RUN_ARGS+=(-it)
fi

DOCKER_CMD=(docker run "${DOCKER_RUN_ARGS[@]}" -v "$code_dir:$mount_dir" --network none --rm sgx.build.env)

if [ $type_flag = 0 ]; then
  "${DOCKER_CMD[@]}"
else
  "${DOCKER_CMD[@]}" /bin/bash -c "$mount_dir/cmd.sh"
fi
