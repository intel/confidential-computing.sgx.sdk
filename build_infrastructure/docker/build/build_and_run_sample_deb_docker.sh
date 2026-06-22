#!/bin/sh
#
# Copyright(c) 2022-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e
docker build --target sample_deb --build-arg https_proxy=$https_proxy \
             --build-arg http_proxy=$http_proxy -t sgx_sample_deb -f ./Dockerfile ../../

# In-kernel driver (5.11+) uses /dev/sgx_enclave.

# The SGX SDK sample built here (SGX SDK SampleEnclave) does NOT use the AESM, so it is OFF by
# default; currently it is used by some DCAP-based quote-generation samples or RA-TLS (which may talk
# to the AESM for PCE/QE3 out-of-process quoting).
# USE_AESM=1 mounts an external AESM socket bound at /var/run/aesmd (its well-known default). 
# AESM_SOCKET_DIR picks the source: 
#  - a named volume (e.g. 'aesmd-socket'[default] from build_and_run_aesm_deb_docker.sh, which is a tmpfs
#    volume shared between the sample and AESM containers), or
#  - a host path (e.g. /var/run/aesmd)
USE_AESM="${USE_AESM:-0}"   # flip to 1 to attach an external AESM
[ "$USE_AESM" = "1" ] && AESM_ARGS="-v ${AESM_SOCKET_DIR:-aesmd-socket}:/var/run/aesmd" || AESM_ARGS=""

# Add host "sgx" group when present (systemd >= 248 sets /dev/sgx_enclave to
# root:sgx 0660; older systemd / tarball installs use 0666 and have no group).
sgx_gid=$(getent group sgx 2>/dev/null | cut -d: -f3)
GROUP_ARGS=${sgx_gid:+--group-add $sgx_gid}

docker run --rm --name sgx_sample --env http_proxy --env https_proxy \
  --device=/dev/sgx_enclave \
  $GROUP_ARGS \
  $AESM_ARGS -it sgx_sample_deb
