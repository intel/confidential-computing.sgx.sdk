#!/usr/bin/env bash
#
# Copyright (C) 2011-2021 Intel Corporation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#   * Neither the name of Intel Corporation nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#

ARG1=${1:-build}
project_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "project_dir is $project_dir"
sgxssl_dir=$project_dir/sgxssl
openssl_out_dir=$sgxssl_dir/openssl_source
openssl_ver_name=openssl-3.0.20
intel_sgx_ssl_url=https://github.com/intel/intel-sgx-ssl
# Latest intel-sgx-ssl release tag (OpenSSL 3.0.20) instead of the in-development branch.
sgxssl_release_tag=3.0_Rev5.3
build_script=$sgxssl_dir/Linux/build_openssl.sh
server_url_path=https://www.openssl.org/source
full_openssl_url=$server_url_path/$openssl_ver_name.tar.gz
full_openssl_url_old=$server_url_path/old/3.0/$openssl_ver_name.tar.gz

FileExists() {
	pushd $sgxssl_dir/Linux/
	if [ $SGX_DEBUG == 0 ] ; then
		echo "build release mode openssl"
		make clean sgxssl_no_mitigation
	else
		echo "build debug mode openssl"
		make clean sgxssl_no_mitigation DEBUG=1
	fi
	echo "build sgxssl completed"
	popd
}

# The released Intel(R) SGX SSL build_openssl.sh builds the crypto library only
# (libsgx_tsgxssl_crypto[d].a). This sample terminates the TLS session INSIDE the
# enclave, so it also needs the trusted libssl (the SSL_* protocol API). OpenSSL's
# Configure already produced a Makefile that can build libssl.a from the very same
# tree, with the identical SGX build flags (sgx_config.conf + mitigations) that
# build_openssl.sh baked in via `perl Configure` -- so `make libssl.a` compiles
# ssl/*.o with the same flags as libcrypto.a. We then apply the exact same
# post-processing build_openssl.sh applies to libcrypto: an objcopy that renames the
# .init section (an SGX requirement -- enclaves can't carry a standard .init section).
BuildSslLib() {
	local ossl_build_dir=$openssl_out_dir/$openssl_ver_name
	local pkg_lib=$sgxssl_dir/Linux/package/lib64
	local ssl_out=libsgx_tsgxssl_ssl.a
	if [ -f $pkg_lib/libsgx_tsgxssl_cryptod.a ]; then
		ssl_out=libsgx_tsgxssl_ssld.a
	fi
	if [ -f $pkg_lib/$ssl_out ]; then
		echo "trusted libssl ($ssl_out) already present, skipping"
		return 0
	fi
	# Reuse upstream's own .init rename argument so the value is provably theirs.
	local init_rename
	init_rename=$(grep -o -- '--rename-section[[:space:]]*\.init=[^[:space:]]*' "$build_script" | head -1)
	if [ -z "$init_rename" ]; then
		echo "ERROR: could not find the .init rename step in $build_script;" \
		     "upstream build_openssl.sh format changed, please re-check." >&2
		exit 1
	fi
	echo "building trusted libssl ($ssl_out) for in-enclave TLS"
	# Same sequence build_openssl.sh runs for libcrypto, applied to libssl:
	#   make libssl.a -> cp into package/lib64 -> objcopy .init rename
	make -C $ossl_build_dir libssl.a || exit 1
	cp $ossl_build_dir/libssl.a $pkg_lib/$ssl_out || exit 1
	objcopy $init_rename $pkg_lib/$ssl_out || exit 1
	echo "trusted libssl built -> $pkg_lib/$ssl_out"
}

debug=false

if [ $debug == true ] ; then
	read -n 1 -p "download souce code only, because we need to build ourselves"
fi

openssl_chksum=c80a01dfc70ece4dc21168932c37739042d404d46ccc81a5986dd75314ecda6f
rm -f check_sum_openssl.txt
if [ ! -f $build_script ]; then
    git clone $intel_sgx_ssl_url -b $sgxssl_release_tag $sgxssl_dir || exit 1  
fi

if [ ! -f $openssl_out_dir/$openssl_ver_name.tar.gz ]; then
	wget $full_openssl_url_old -P $openssl_out_dir || wget $full_openssl_url -P $openssl_out_dir || exit 1
	sha256sum $openssl_out_dir/$openssl_ver_name.tar.gz > $sgxssl_dir/check_sum_openssl.txt
	echo "downloading OPENSSL source code now..." 
	grep $openssl_chksum $sgxssl_dir/check_sum_openssl.txt
	if [ $? -ne 0 ]; then
    	echo "File $openssl_out_dir/$openssl_ver_name.tar.gz checksum failure"
        rm -f $openssl_out_dir/$openssl_ver_name.tar.gz
    	exit -1
	fi
fi


if [ "$1" = "nobuild" ]; then
	exit 0
fi

if [ $debug == false ] ; then
	echo "only when debug is turned off, can script go here"
	FileExists
	BuildSslLib
	echo "endof of build sgxssl" && exit 0
fi

echo "end of script"
