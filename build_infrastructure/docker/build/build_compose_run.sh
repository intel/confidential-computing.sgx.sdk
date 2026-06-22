#!/bin/sh
#
# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

# Support both docker-compose (v1) and docker compose (v2)
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

# INSTALL_DCAP_QPL installs the Quote Provider Library into the AESM image so it can fetch
# PCK collateral for a full DCAP quote. Default on. Set INSTALL_DCAP_QPL=0 to run a quote
# sample WITHOUT any PCK provider: the AESM emits an encrypted-PPID quote (cert type 3),
# which needs no PCCS/PCS but cannot be verified into a PCK cert chain.
#
# With the QPL, the AESM reads "pccs_url" from the QCNL config baked into the image
# (default https://host.docker.internal:8081, a PCCS on the Docker host). Point it at a
# different provider via --build-arg PCCS_HOST_URL=<url> (or bind-mount your own conf):
#   - host PCCS (default): also add 'extra_hosts: ["host.docker.internal:host-gateway"]' to
#     the aesm service; https://host.docker.internal:8081/sgx/certification/v4/;
#   - peer PCCS: also add a pccs service to docker-compose.yml; https://pccs:8081/... (the
#     compose service name resolves on the shared network);
#   - Intel PCS directly (no PCCS): https://api.trustedservices.intel.com/... + PCS API key.
INSTALL_DCAP_QPL="${INSTALL_DCAP_QPL:-1}"

docker build  --target aesm_deb --build-arg https_proxy=$https_proxy \
              --build-arg http_proxy=$http_proxy --build-arg INSTALL_DCAP_QPL="$INSTALL_DCAP_QPL" \
              -t sgx_aesm -f ./Dockerfile ../../

docker build --target sample_deb --build-arg https_proxy=$https_proxy \
             --build-arg http_proxy=$http_proxy -t sgx_sample -f ./Dockerfile ../../

docker volume create --driver local --opt type=tmpfs --opt device=tmpfs --opt o=rw aesmd-socket

# Resolve host SGX group GIDs for group_add in the yml (dynamic, not stable across
# hosts): "sgx" (systemd >= 248, /dev/sgx_enclave) and "sgx_prv" (Intel libsgx-ae-pce,
# /dev/sgx_provision). Missing groups fall back to nogroup (65534), an unprivileged GID.
#
# USE_AESM brings up the AESM container. Default on (full stack); set USE_AESM=0 to run
# only the sample container (the SGX SDK sample does not need the AESM).
[ "${USE_AESM:-1}" = "0" ] && RUN_SERVICES="--no-deps sample" || RUN_SERVICES=""
SGX_GID=$(getent group sgx 2>/dev/null | cut -d: -f3) \
SGX_PRV_GID=$(getent group sgx_prv 2>/dev/null | cut -d: -f3) \
    $DOCKER_COMPOSE --verbose up $RUN_SERVICES
