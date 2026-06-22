#!/usr/bin/env bash
#
# Copyright(c) 2011-2025 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

top_dir=$(dirname "$0")
out_dir=$top_dir
dcap_version=1.27
prebuilt_file_name=prebuilt_dcap_${dcap_version}.tar.gz
checksum_file=SHA256SUM_prebuilt_dcap_${dcap_version}.cfg
server_url_path=https://download.01.org/intel-sgx/sgx-dcap/${dcap_version}/linux/
server_ae_url=$server_url_path/$prebuilt_file_name
server_checksum_url=$server_url_path/$checksum_file

rm -rf "${out_dir:?}/$prebuilt_file_name"
if ! wget "$server_ae_url" -P "$out_dir"; then
    echo "Fail to download file $server_ae_url"
    exit 1
fi

rm -f "$out_dir/$checksum_file"
if ! wget "$server_checksum_url" -P "$out_dir"; then
    echo "Fail to download file $server_checksum_url"
    exit 1
fi

pushd "$out_dir" || exit

if ! sha256sum -c "$checksum_file"; then
    echo "Checksum verification failure"
    exit 1
fi

if [ -d prebuilt ]; then
    rm -rf prebuilt
fi

tar -zxf "$prebuilt_file_name" prebuilt/openssl || { echo "Fail to extract $prebuilt_file_name"; exit 1; }
if ! { mkdir -p prebuilt/dcap && mv prebuilt/openssl prebuilt/dcap/openssl; }; then
    echo "Fail to move OpenSSL prebuilts into prebuilt/dcap/openssl"
    exit 1
fi
rm -f "$prebuilt_file_name"
rm -f "$checksum_file"

popd || exit
