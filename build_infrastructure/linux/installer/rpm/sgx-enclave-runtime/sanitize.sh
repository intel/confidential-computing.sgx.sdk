#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#


set -e

tarball="linux-sgx_sgx-enclave-runtime"
enclave_runtime="sgx-enclave-runtime"

cur_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="${cur_dir}/../../../../.."
common_dir="${root_dir}/build_infrastructure/linux/installer/common"
common_enclave_runtime_dir="${common_dir}/${enclave_runtime}"
tarball_dir="${cur_dir}/${tarball}"

make -C ${root_dir} preparation

python3 ${common_dir}/gen_source/copy_source.py                                       \
      --bom-file ${common_enclave_runtime_dir}/BOM_source/sgx-enclave-runtime-tarball.txt \
      --src-path ${root_dir}                                                          \
      --dst-path ${tarball_dir}                                                       \
      --cleanup

tar -zcvf ${cur_dir}/${tarball}.tar.gz -C ${cur_dir} ${tarball}
rm -fr ${tarball_dir}
