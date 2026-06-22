#!/bin/sh
#
# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

# Standalone AESM that backs quoting samples out-of-process. See the "Standalone AESM container"
# section in README.md for the rationale behind these defaults; all three are pass-through build-args.
QUOTE_PROVIDER="${QUOTE_PROVIDER:-dcap_aesm}"
INSTALL_DCAP_QPL="${INSTALL_DCAP_QPL:-1}"
COLLATERAL_PROVIDER="${COLLATERAL_PROVIDER:-pccs-host}"

# Shared local-artifact helpers: resolve SGX_VERSION_ARG + SGX_OVERRIDE_* and stage them; see README.md.
. "$(dirname "$0")/helpers/common-defaults.sh"
sd_stage_local_artifacts && trap 'sd_cleanup_local_artifacts' EXIT INT TERM

docker build --target aesm --build-arg https_proxy=$https_proxy \
             --build-arg http_proxy=$http_proxy \
             --build-arg QUOTE_PROVIDER="$QUOTE_PROVIDER" \
             --build-arg INSTALL_DCAP_QPL="$INSTALL_DCAP_QPL" \
             --build-arg COLLATERAL_PROVIDER="$COLLATERAL_PROVIDER" \
             $SGX_VERSION_ARG -t sgx_aesm -f ./Dockerfile ./

docker volume create --driver local --opt type=tmpfs --opt device=tmpfs --opt o=rw aesmd-socket

# Targets the in-kernel SGX driver (5.11+): /dev/sgx_enclave and /dev/sgx_provision. For the
# legacy out-of-tree driver (/dev/isgx, no provisioning device) see README.md.

# Build the "--group-add <gid>" set for the host SGX groups that exist: "sgx" (created by a
# systemd udev rule on /dev/sgx_enclave) and "sgx_prv" (/dev/sgx_provision); each is skipped
# if absent (0666 nodes, no group).
GROUP_ARGS=$(sd_group_add_flags sgx sgx_prv)

docker run --init --rm --name sgx_aesm --env http_proxy --env https_proxy \
  --device=/dev/sgx_enclave --device=/dev/sgx_provision \
  $GROUP_ARGS \
  -v /dev/log:/dev/log -v aesmd-socket:/var/run/aesmd -it sgx_aesm
