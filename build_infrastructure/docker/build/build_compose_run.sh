#!/bin/sh
#
# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e
SAMPLE_NAME="${SAMPLE_NAME:-SampleEnclave}"

# Limitation: this lightweight sample_deb compose flow does not provision the
# DCAP quoting stack needed by SampleAttestedTLS, so that sample is not
# supported here.
if [ "$SAMPLE_NAME" = "SampleAttestedTLS" ]; then
    echo "ERROR: SAMPLE_NAME=SampleAttestedTLS is not supported by build_compose_run.sh (requires DCAP quoting setup)." >&2
    exit 1
fi

# Support both docker-compose (v1) and docker compose (v2)
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

docker build --target sample_deb --build-arg https_proxy=$https_proxy \
             --build-arg http_proxy=$http_proxy \
             --build-arg SAMPLE_NAME="$SAMPLE_NAME" \
             -t sgx_sample -f ./Dockerfile ../../../

# Resolve host SGX group GIDs for group_add in the yml (dynamic, not stable across
# hosts): "sgx" (systemd >= 248, /dev/sgx_enclave).
# Missing group falls back to nogroup (65534), an unprivileged GID.
SGX_GID=$(getent group sgx 2>/dev/null | cut -d: -f3) \
    $DOCKER_COMPOSE --verbose up
