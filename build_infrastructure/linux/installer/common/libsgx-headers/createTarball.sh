#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR="${SCRIPT_DIR}/../../../../"
LINUX_INSTALLER_DIR="${ROOT_DIR}/linux/installer"
LINUX_INSTALLER_COMMON_DIR="${LINUX_INSTALLER_DIR}/common"

INSTALL_PATH=${SCRIPT_DIR}/output

# Cleanup
rm -fr ${INSTALL_PATH}

# Get the configuration for this package
source ${SCRIPT_DIR}/installConfig

# Fetch the gen_source script
cp ${LINUX_INSTALLER_COMMON_DIR}/gen_source/gen_source.py ${SCRIPT_DIR}

# Copy the files according to the BOM
python3 ${SCRIPT_DIR}/gen_source.py --bom=BOMs/libsgx-headers.txt --deliverydir=${ROOT_DIR} --installdir=pkgroot/libsgx-headers
python3 ${SCRIPT_DIR}/gen_source.py --bom=BOMs/libsgx-headers-package.txt --deliverydir=${ROOT_DIR} --cleanup=false
python3 ${SCRIPT_DIR}/gen_source.py --bom=../licenses/BOM_license.txt --deliverydir=${ROOT_DIR} --cleanup=false

# Create the tarball
pushd ${INSTALL_PATH} &> /dev/null
tar -zcvf ${TARBALL_NAME} *
popd &> /dev/null
