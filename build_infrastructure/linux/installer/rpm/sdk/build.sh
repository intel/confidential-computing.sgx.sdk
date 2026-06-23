#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
ROOT_DIR="$(readlink -f "${SCRIPT_DIR}/../../../../..")"

PKG_OUT_ROOT_DIR="${PKG_OUT_ROOT_DIR:-${ROOT_DIR}/build_infrastructure/linux/installer}"
FLATTEN_PKG_OUT_DIR="${FLATTEN_PKG_OUT_DIR:-0}"
RPM_OUT_DIR="${PKG_OUT_ROOT_DIR}/rpm$([ "$FLATTEN_PKG_OUT_DIR" = 0 ] && echo /sdk || true)"

cd "${ROOT_DIR}" #for relative path resolution

LINUX_INSTALLER_DIR="${ROOT_DIR}/build_infrastructure/linux/installer"
LINUX_INSTALLER_COMMON_DIR="${LINUX_INSTALLER_DIR}/common"
LINUX_INSTALLER_COMMON_SDK_DIR="${LINUX_INSTALLER_COMMON_DIR}/sdk"
LINUX_OS_ID=$(grep "^ID=" /usr/lib/os-release 2> /dev/null | awk -F'=' '{print $2}')

RPM_HELER_COMMAND="exit 0"

source ${LINUX_INSTALLER_COMMON_SDK_DIR}/installConfig.x64
if [ "${LINUX_OS_ID}" = "clear-linux-os" ]; then
    SGX_PACKAGES_PATH=/usr/share
    RPM_HELER_COMMAND="echo"
fi

SDK_PKG_VERSION=${SDK_VERSION:-$(awk '/#define STRFILEVER_DEFAULT/ {print $3}' ${ROOT_DIR}/common/inc/internal/se_version.h|sed 's/^\"\(.*\)\"$/\1/')}
RPM_BUILD_FOLDER=${SDK_PKG_NAME}-${SDK_PKG_VERSION}

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
    cp -f ${SCRIPT_DIR}/${SDK_PKG_NAME}.spec ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}/SPECS
}

post_build() {
    # If PKG_OUT_ROOT_DIR is non-default, move the resulting packages to the target dir.
    if [ "${SCRIPT_DIR}" != "$(readlink -f "${RPM_OUT_DIR}")" ]; then
        mkdir -p "${RPM_OUT_DIR}"
        for FILE in $(find ${SCRIPT_DIR}/${RPM_BUILD_FOLDER} -name "*.rpm" 2> /dev/null); do
            mv "${FILE}" "${RPM_OUT_DIR}"
        done
    fi
    rm -fR ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}
}

update_spec() {
    pushd ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}
    sed -i "s#@version@#${SDK_PKG_VERSION}#" SPECS/${SDK_PKG_NAME}.spec
    
    # RPM %changelog requires English format "Day Mon DD YYYY"; use LC_ALL=C to force English locale
    BUILD_DATE=$(LC_ALL=C date +"%a %b %d %Y")
    sed -i "s#@date@#${BUILD_DATE}#" SPECS/${SDK_PKG_NAME}.spec
    
    sed -i "s#@install_path@#${SGX_PACKAGES_PATH}/${SDK_PKG_NAME}#" SPECS/${SDK_PKG_NAME}.spec
    sed -i "s#@helper_command@#${RPM_HELER_COMMAND}#" SPECS/${SDK_PKG_NAME}.spec
    popd
}

create_upstream_tarball() {
    ${LINUX_INSTALLER_COMMON_SDK_DIR}/createTarball.sh
    tar -xvf ${LINUX_INSTALLER_COMMON_SDK_DIR}/output/${TARBALL_NAME} -C ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}/SOURCES
    pushd ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}/SOURCES
    # change the install path to /usr/share instead of /opt/intel if the OS is clear linux
    sed -i "s#\(SGX_PACKAGES_PATH=\).*#\1${SGX_PACKAGES_PATH}#" scripts/installConfig
    tar -zcvf ${RPM_BUILD_FOLDER}$(echo ${TARBALL_NAME}|awk -F'.' '{print "."$(NF-1)"."$(NF)}') *
    popd
}

build_rpm_package() {
    pushd ${SCRIPT_DIR}/${RPM_BUILD_FOLDER}
    rpmbuild --define="_topdir `pwd`" --define='debug_package %{nil}' -ba SPECS/${SDK_PKG_NAME}.spec
    popd
}

main $@
