#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

top_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
openssl_out_dir=$top_dir/openssl_source
openssl_ver=3.0.21
openssl_ver_name=openssl-$openssl_ver
sgxssl_github_archive=https://github.com/intel/intel-sgx-ssl/archive
sgxssl_file_name=3.0_Rev5.4
build_script=$top_dir/Linux/build_openssl.sh
server_url_path=https://www.openssl.org/source
full_openssl_url=$server_url_path/$openssl_ver_name.tar.gz

sgxssl_chksum=e6891fa0e527de24d241343e593b7ccfb516bd44564415bfbee0228a82387e3e
openssl_chksum=617e29af8e421f46649484a4937e48c685e47f46488167c982f88bc4ec1d522f
rm -f check_sum_sgxssl.txt check_sum_openssl.txt
if [ ! -f $build_script ]; then
    wget $sgxssl_github_archive/$sgxssl_file_name.zip -P $top_dir || exit 1
    sha256sum $top_dir/$sgxssl_file_name.zip > check_sum_sgxssl.txt
    grep $sgxssl_chksum check_sum_sgxssl.txt
    if [ $? -ne 0 ]; then
        echo "File $top_dir/$sgxssl_file_name.zip checksum failure"
        rm -f $top_dir/$sgxssl_file_name.zip
        exit -1
    fi
    unzip -qq $top_dir/$sgxssl_file_name.zip -d $top_dir || exit 1
    mv $top_dir/intel-sgx-ssl-$sgxssl_file_name/* $top_dir || exit 1
    rm $top_dir/$sgxssl_file_name.zip || exit 1
    rm -rf $top_dir/intel-sgx-ssl-$sgxssl_file_name || exit 1
fi

if [ ! -f $openssl_out_dir/$openssl_ver_name.tar.gz ]; then
    wget $full_openssl_url -P $openssl_out_dir --no-check-certificate || exit 1
    sha256sum $openssl_out_dir/$openssl_ver_name.tar.gz > check_sum_openssl.txt
    grep $openssl_chksum check_sum_openssl.txt
    if [ $? -ne 0 ]; then
        echo "File $openssl_out_dir/$openssl_ver_name.tar.gz checksum failure"
        rm -f $openssl_out_dir/$openssl_ver_name.tar.gz
        exit -1
    fi
fi

pushd $top_dir/Linux/
if [ "$MITIGATION" != "" ]; then
    make clean all LINUX_SGX_BUILD=1 DEBUG=$DEBUG
else
    make clean sgxssl_no_mitigation LINUX_SGX_BUILD=1 DEBUG=$DEBUG
fi
popd
