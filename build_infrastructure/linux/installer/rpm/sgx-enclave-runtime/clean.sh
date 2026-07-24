#!/usr/bin/env bash
#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#


set -e

cur_dir="$(cd "$(dirname "$0")" && pwd)"

rm -rf "${cur_dir}/linux-sgx_sgx-enclave-runtime/"
rm -f "${cur_dir}"/{*.rpm,*.tar.gz,*.spec.in}
