#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

# Note: this script can build SDK only, but retaining the 'psw' positional arg for backward-compat.
[[ $# -le 2 ]] || {
    echo "Usage : ./build-installpkg.sh [sdk] [cve-option]"
    exit 1
}

INSTALLER_TYPE="${1:-sdk}"
# If first arg looks like a flag/cve-option (not a recognized installer type),
# treat it as cve-option and use default installer
if [[ "$INSTALLER_TYPE" != "sdk" && "$INSTALLER_TYPE" != "psw" ]]; then
    INSTALLER_TYPE="sdk"
    set -- "sdk" "$@"  # Prepend 'sdk' to positional params so downstream code sees cve-option as $1
fi

if [[ "$INSTALLER_TYPE" == "psw" ]]; then
    echo "ERROR: The PSW installer is no longer supported for this (SGX SDK's) script."
    echo "       Please refer to https://github.com/intel/confidential-computing.sgx/blob/main/linux/installer/bin/build-installpkg.sh for the PSW installer script."
    exit 1
fi

CVE_FLAVOR="${2:-none}"
echo "Building the SGX SDK installer package (CVE flavor: $CVE_FLAVOR)"

SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
ROOT_DIR="$(readlink -f "${SCRIPT_DIR}/../../../..")"

cd "${ROOT_DIR}" # for relative path resolution

PKG_OUT_ROOT_DIR="${PKG_OUT_ROOT_DIR:-${ROOT_DIR}/build_infrastructure/linux/installer}"
BIN_OUT_DIR="${PKG_OUT_ROOT_DIR}/bin"
LINUX_INSTALLER_COMMON_DIR="${ROOT_DIR}/build_infrastructure/linux/installer/common"
LINUX_INSTALLER_COMMON_SDK_DIR="${LINUX_INSTALLER_COMMON_DIR}/sdk"

# The result dir of the build
BUILD_DIR=${ROOT_DIR}/build/linux

if [[ ! -f "$BUILD_DIR/sgx_sign" ]]; then
    echo "ERROR: sgx_sign not found at $BUILD_DIR/sgx_sign"
    echo "       The SGX SDK must be built first before creating the installer package."
    echo "       Please run 'make' in the SDK root directory."
    exit 1
fi

# Get the architecture of the build from generated binary
get_arch()
{
    local a=$(readelf -h $BUILD_DIR/sgx_sign | sed -n '2p' | awk '{print $6}')
    test $a = 01 && echo 'x86' || echo 'x64'
}
 

ARCH=$(get_arch)
PACKAGE_SUFFIX="$ARCH"

source ${LINUX_INSTALLER_COMMON_SDK_DIR}/installConfig.${PACKAGE_SUFFIX}
${LINUX_INSTALLER_COMMON_SDK_DIR}/createTarball.sh ${2:-}
cp  ${LINUX_INSTALLER_COMMON_SDK_DIR}/output/${TARBALL_NAME} ${SCRIPT_DIR}

mkdir -p "${BIN_OUT_DIR}"


trap "rm -f ${SCRIPT_DIR}/$TARBALL_NAME 2>/dev/null" 0

# Create the tarball and compute its MD5 check sum.
m=$(md5sum ${SCRIPT_DIR}/$TARBALL_NAME | awk '{print $1}')
v=${SDK_VERSION:-${SDK_PKG_VERSION_DEFAULT:-$(awk '/#define STRFILEVER_DEFAULT/ {print $3}' ${ROOT_DIR}/common/inc/internal/se_version.h|sed 's/^\"\(.*\)\"$/\1/')}}
TEMPLATE_FILE=$SCRIPT_DIR/install-sgx-"$INSTALLER_TYPE".bin.tmpl
INSTALLER_NAME=${BIN_OUT_DIR}/sgx_linux_"${PACKAGE_SUFFIX}"_"$INSTALLER_TYPE"_"$v".bin
l=$(wc -l $TEMPLATE_FILE | awk '{print $1}')
l=$(($l+1))

sed -e "s:@linenum@:$l:" \
    -e "s:@md5sum@:$m:"  \
    -e "s:@arch@:$ARCH:"  \
    $TEMPLATE_FILE > $INSTALLER_NAME

cat ${SCRIPT_DIR}/${TARBALL_NAME} >> $INSTALLER_NAME
chmod +x $INSTALLER_NAME
echo "Generated ${INSTALLER_TYPE} installer: $INSTALLER_NAME"
exit 0
