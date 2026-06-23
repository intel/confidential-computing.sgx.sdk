#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#


set -e

SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
ROOT_DIR="$(readlink -f "${SCRIPT_DIR}/../../../../..")"

PKG_OUT_ROOT_DIR="${PKG_OUT_ROOT_DIR:-${ROOT_DIR}/build_infrastructure/linux/installer}"
FLATTEN_PKG_OUT_DIR="${FLATTEN_PKG_OUT_DIR:-0}"
DEB_OUT_DIR="${PKG_OUT_ROOT_DIR}/deb$([ "$FLATTEN_PKG_OUT_DIR" = 0 ] && echo /libsgx-enclave-common || true)"

cd "${ROOT_DIR}" #for relative path resolution

LINUX_INSTALLER_DIR="${ROOT_DIR}/build_infrastructure/linux/installer"
LINUX_INSTALLER_COMMON_DIR="${LINUX_INSTALLER_DIR}/common"
LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR="${LINUX_INSTALLER_COMMON_DIR}/libsgx-enclave-common"

source ${LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR}/installConfig
DEB_FOLDER=${ENCLAVE_COMMON_PACKAGE_NAME}-${ENCLAVE_COMMON_VERSION}

ENCLAVE_RUNTIME_PKG_VERSION=${ENCLAVE_RUNTIME_VERSION:-$(awk '/#define STRFILEVER_DEFAULT/ {print $3}' ${ROOT_DIR}/common/inc/internal/se_version.h|sed 's/^\"\(.*\)\"$/\1/')}
DEB_BUILD_FOLDER=${ENCLAVE_COMMON_PACKAGE_NAME}-${ENCLAVE_RUNTIME_PKG_VERSION}

main() {
    pre_build
    create_upstream_tarball
    unpack_upstream_tarball
    generate_install
    generate_copyright
    update_version
    rename_tarball
    build_deb_package
    post_build
}

pre_build() {
    rm -fR ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}
    cp -fR ${SCRIPT_DIR}/${DEB_FOLDER} ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}
}

post_build() {
    # If PKG_OUT_ROOT_DIR is non-default, move the resulting packages to the target dir.
    if [ "${SCRIPT_DIR}" != "$(readlink -f "${DEB_OUT_DIR}")" ]; then
        mkdir -p "${DEB_OUT_DIR}"
        for FILE in $(find ${SCRIPT_DIR} -maxdepth 1 -type f \( -name "*.deb" -o -name "*.ddeb" \) 2> /dev/null); do
            mv "${FILE}" "${DEB_OUT_DIR}"
        done
    fi
    rm -fR ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}
}

create_upstream_tarball() {
    ${LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR}/createTarball.sh
    cp ${LINUX_INSTALLER_COMMON_ENCLAVE_COMMON_DIR}/output/${TARBALL_NAME} ${SCRIPT_DIR}
}

unpack_upstream_tarball() {
    pushd ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}
    cp ../${TARBALL_NAME} .
    tar xvf ${TARBALL_NAME}
    rm -f ${TARBALL_NAME}
    popd
}

generate_install() {
    echo "debian/tmp/${ENCLAVE_COMMON_PACKAGE_NAME}/* ." > ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}/debian/${ENCLAVE_COMMON_PACKAGE_NAME}.install
    echo "debian/tmp/${ENCLAVE_COMMON_DEV_PACKAGE_NAME}/* ." > ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}/debian/${ENCLAVE_COMMON_DEV_PACKAGE_NAME}.install
}

generate_copyright() {
    pushd ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}
    rm -f debian/copyright
    find package/licenses/ -type f -print0 | xargs -0 -n1 cat >> debian/copyright
    popd
}

get_os_code() {
    OS_CODE=$(lsb_release -cs 2> /dev/null)
    if [ -z ${OS_CODE} ]; then
        OS_CODE=$(grep "VERSION_CODENAME" /etc/os-release 2> /dev/null | cut -d= -f2)
    fi
    echo ${OS_CODE}
}

update_version() {
    pushd ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}
    INS_VERSION=$(echo $(dpkg-parsechangelog |grep "Version" | cut -d: -f2))
    DEB_VERSION=$(echo $INS_VERSION | cut -d- -f2)

    FULL_VERSION=${ENCLAVE_RUNTIME_PKG_VERSION}-$(get_os_code)${DEB_VERSION}
    sed -i "s/${INS_VERSION}/${FULL_VERSION}/" debian/changelog
    sed -i "s/@dep_version@/${FULL_VERSION}/g" debian/control
    popd
}

rename_tarball() {
    TARBALL_NAME_NEW_VERSION=$(echo ${TARBALL_NAME} | sed "s/${ENCLAVE_COMMON_VERSION}/${ENCLAVE_RUNTIME_PKG_VERSION}/")
    mv ${SCRIPT_DIR}/${TARBALL_NAME} ${SCRIPT_DIR}/${TARBALL_NAME_NEW_VERSION}
}

build_deb_package() {
    pushd ${SCRIPT_DIR}/${DEB_BUILD_FOLDER}
    SOURCE_DATE_EPOCH="$(date +%s)" dpkg-buildpackage -us -uc
    popd
}

main $@
