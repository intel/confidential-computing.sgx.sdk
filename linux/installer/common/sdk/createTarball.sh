#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR="${SCRIPT_DIR}/../../../../"
BUILD_DIR="${ROOT_DIR}/build/linux"
LINUX_INSTALLER_DIR="${ROOT_DIR}/linux/installer"
LINUX_INSTALLER_COMMON_DIR="${LINUX_INSTALLER_DIR}/common"

INSTALL_PATH=${SCRIPT_DIR}/output

# Cleanup
rm -fr ${INSTALL_PATH}

# Get the architecture of the build from generated binary
get_arch()
{
    local a=$(readelf -h $BUILD_DIR/sgx_sign | sed -n '2p' | awk '{print $6}')
    test $a = 01 && echo 'x86' || echo 'x64'
}

ARCH=$(get_arch)

# Get the configuration for this package
source ${SCRIPT_DIR}/installConfig.${ARCH}

generate_pkgconfig_files() {
    local TEMPLATE_FOLDER=${SCRIPT_DIR}/pkgconfig/template
    local TARGET_FOLDER=${SCRIPT_DIR}/pkgconfig/${ARCH}
    local VERSION="$1"

    # Create pkgconfig folder for this architecture
    rm -fr ${TARGET_FOLDER}
    mkdir -p ${TARGET_FOLDER}

    # Copy the template files into the folder
    for pkgconfig_file in $(ls -1 ${TEMPLATE_FOLDER}); do
        sed -e "s:@LIB_FOLDER_NAME@:$LIB_DIR:" \
            -e "s:@SGX_VERSION@:$VERSION:" \
            ${TEMPLATE_FOLDER}/$pkgconfig_file > ${TARGET_FOLDER}/$pkgconfig_file
    done
}

# Get Intel(R) SGX version
SGX_VERSION=$(awk '/STRFILEVER/ {print $3}' ${ROOT_DIR}/common/inc/internal/se_version.h|sed 's/^\"\(.*\)\"$/\1/')

# Generate pkgconfig files
generate_pkgconfig_files $SGX_VERSION

# Fetch the gen_source script
cp ${LINUX_INSTALLER_COMMON_DIR}/gen_source/gen_source.py ${SCRIPT_DIR}

# Copy the files according to the BOM
python3 ${SCRIPT_DIR}/gen_source.py --bom=BOMs/sdk_base.txt --deliverydir=${ROOT_DIR}
python3 ${SCRIPT_DIR}/gen_source.py --bom=BOMs/sdk_${ARCH}.txt --deliverydir=${ROOT_DIR} --cleanup=false
if [ "$1" = "cve-2020-0551" ]; then 
    python3 ${SCRIPT_DIR}/gen_source.py --bom=BOMs/sdk_cve_2020_0551_load.txt --deliverydir=${ROOT_DIR} --cleanup=false
    python3 ${SCRIPT_DIR}/gen_source.py --bom=BOMs/sdk_cve_2020_0551_cf.txt --deliverydir=${ROOT_DIR} --cleanup=false
fi
python3 ${SCRIPT_DIR}/gen_source.py --bom=../licenses/BOM_license.txt --deliverydir=${ROOT_DIR} --cleanup=false

# Create the tarball
pushd ${INSTALL_PATH} &> /dev/null
tar -zcvf ${TARBALL_NAME} *
popd &> /dev/null
