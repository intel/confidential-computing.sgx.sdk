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
LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR="${LINUX_INSTALLER_COMMON_DIR}/libsgx-enclave-common"

source ${LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR}/installConfig

SGX_VERSION=$(awk '/STRFILEVER/ {print $3}' ${ROOT_DIR}/common/inc/internal/se_version.h|sed 's/^\"\(.*\)\"$/\1/')
RPM_BUILD_FOLDER=${ENCLAVE_COMMON_PACKAGE_NAME}-${SGX_VERSION}

main() {
    pre_build
    update_spec
    create_upstream_tarball
    build_rpm_package
    post_build
}

pre_build() {
    rm -fR ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}
    mkdir -p ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cp -f ${SCRIPT_DIR}/${ENCLAVE_COMMON_PACKAGE_NAME}.spec ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}/SPECS
}

post_build() {
    for FILE in $(find ${SCRIPT_DIR}/${RPM_BUILD_FOLDER} -name "*.rpm" 2> /dev/null); do
        cp "${FILE}" ${SCRIPT_DIR}
    done
    rm -fR ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}
}

update_spec() {
    min_version="4.12"
    rpm_version=$(rpmbuild --version 2> /dev/null | awk '{print $NF}')
    cur_version=$(echo -e "${rpm_version}\n${min_version}" | sort -V | head -n 1)

    pushd ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}
    sed -i "s/@version@/${SGX_VERSION}/" SPECS/${ENCLAVE_COMMON_PACKAGE_NAME}.spec
    if [ "${min_version}" != "${cur_version}" ]; then
        sed -i "s/^Recommends:/Requires:  /" SPECS/${ENCLAVE_COMMON_PACKAGE_NAME}.spec
    fi
    popd
}

create_upstream_tarball() {
    ${LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR}/createTarball.sh
    tar -xvf ${LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR}/output/${TARBALL_NAME} -C ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}/SOURCES
    pushd ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}/SOURCES
    tar -zcvf ${RPM_BUILD_FOLDER}$(echo ${TARBALL_NAME}|awk -F'.' '{print "."$(NF-1)"."$(NF)}') *
    popd
}

build_rpm_package() {
    pushd ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}
    rpmbuild --define="_topdir `pwd`" --define='_debugsource_template %{nil}' --define='debug_package %{nil}' -ba SPECS/${ENCLAVE_COMMON_PACKAGE_NAME}.spec
    popd
}

main $@
