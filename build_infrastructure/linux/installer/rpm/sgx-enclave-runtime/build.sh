#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#

# This packages the live source tree as-is (full tar, no BOM filtering) and runs
# rpmbuild. The build itself (make -C enclave_runtime/urts/linux) needs a *prepared* tree:
# submodules checked out, patches applied, prebuilt openssl/IPP/vtune downloaded.
# A source tree produced by sanitize.sh is already prepared. When running against
# a plain checkout instead, run "make preparation" at the repo root first:
#     make preparation && ./linux/installer/rpm/sgx-enclave-runtime/build.sh

set -e

enclave_runtime="sgx-enclave-runtime"

cur_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "${cur_dir}/../../../../../" && pwd)"
common_dir="${root_dir}/build_infrastructure/linux/installer/common"
common_enclave_runtime_dir="${common_dir}/${enclave_runtime}"

# Package version defaults to the product version in se_version.h (STRFILEVER),
# but can be overridden via the ENCLAVE_RUNTIME_VERSION environment variable.
enclave_runtime_version="${ENCLAVE_RUNTIME_VERSION:-$(awk -F'"' '/#define STRFILEVER_DEFAULT/ {print $2}' \
            ${root_dir}/common/inc/internal/se_version.h)}"
rpm_build_dir=${enclave_runtime}-${enclave_runtime_version}

source "${common_enclave_runtime_dir}/installConfig"

pre_build() {
    rm -fr "${cur_dir}/${rpm_build_dir:?}"
    mkdir -p "${cur_dir}/${rpm_build_dir}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
}

update_spec() {
    local min_version="4.12"
    local rpm_version=$(rpmbuild --version 2> /dev/null | awk '{print $NF}')
    local cur_version=$(echo -e "${rpm_version}\n${min_version}" | sort -V | head -n 1)

    sed -e "s:@enclave_runtime_version@:${enclave_runtime_version}:"            \
        "${cur_dir}/${enclave_runtime}.spec.tmpl" > "${cur_dir}/${rpm_build_dir}/SPECS/${enclave_runtime}.spec"

    if [ "${min_version}" != "${cur_version}" ]; then
        sed -i "s/^Recommends:/Requires:  /" ${cur_dir}/${rpm_build_dir}/SPECS/${enclave_runtime}.spec
    fi
}

create_upstream_tarball() {
    tar -zcvf ${cur_dir}/${rpm_build_dir}/SOURCES/${enclave_runtime}-${enclave_runtime_version}.tar.gz \
        --exclude=$(realpath --relative-to=${root_dir} ${cur_dir})                         \
	--directory=${root_dir} $(ls ${root_dir})
}

build_package() {
    pushd ${cur_dir}/${rpm_build_dir} &> /dev/null
    rpmbuild --define="_topdir `pwd`" --define='_debugsource_template %{nil}' -ba SPECS/${enclave_runtime}.spec
    popd &> /dev/null
}

post_build() {
    find ${cur_dir}/${rpm_build_dir}/RPMS -name '*.rpm' -exec cp -f {} ${cur_dir} \;
    cp -f ${cur_dir}/${rpm_build_dir}/SRPMS/*.rpm ${cur_dir}
    cp -f ${cur_dir}/${rpm_build_dir}/SOURCES/*.tar.gz ${cur_dir}
    cp -f ${cur_dir}/${rpm_build_dir}/SPECS/${enclave_runtime}.spec ${cur_dir}/${enclave_runtime}.spec.in
    rm -fr "${cur_dir}/${rpm_build_dir:?}"
}

main() {
    pre_build
    update_spec
    create_upstream_tarball
    build_package
    post_build
}

main $@
