#!/bin/sh
#
# Copyright(c) 2022-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e
SAMPLE_NAME="${SAMPLE_NAME:-SampleEnclave}"

# Limitation: this lightweight sample_deb flow does not provision the DCAP
# quoting stack needed by SampleAttestedTLS, so that sample is not supported.
if [ "$SAMPLE_NAME" = "SampleAttestedTLS" ]; then
  echo "ERROR: SAMPLE_NAME=SampleAttestedTLS is not supported by build_and_run_sample_deb_docker.sh (requires DCAP quoting setup)." >&2
  exit 1
fi

docker build --target sample_deb --build-arg https_proxy=$https_proxy \
             --build-arg http_proxy=$http_proxy \
             --build-arg SAMPLE_NAME="$SAMPLE_NAME" \
             -t sgx_sample_deb -f ./Dockerfile ../../../

# In-kernel driver (5.11+) uses /dev/sgx_enclave.

# Add host "sgx" group when present (systemd >= 248 sets /dev/sgx_enclave to
# root:sgx 0660; older systemd / tarball installs use 0666 and have no group).
sgx_gid=$(getent group sgx 2>/dev/null | cut -d: -f3)
GROUP_ARGS=${sgx_gid:+--group-add $sgx_gid}

docker run --rm --name sgx_sample --env http_proxy --env https_proxy \
  --device=/dev/sgx_enclave \
  $GROUP_ARGS \
  -it sgx_sample_deb
