#!/bin/sh
#
# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

# Per-script default fed to the shared resolver (helpers/sample-defaults.sh): this single-container
# runner has no AESM of its own, so a DCAP sample prefers in-process quoting. To exercise the
# out-of-process AESM path instead, start an AESM (build_and_run_aesm_docker.sh) and run with
# QUOTE_PROVIDER=dcap_aesm; see "Customization options" in README.md.
DEFAULT_QUOTE_PROVIDER=dcap_in_proc

# Shared sample/build-arg resolver (SGX_VERSION_ARG + SGX_OVERRIDE_* and more); stage local artifacts; see README.md.
. "$(dirname "$0")/helpers/sample-defaults.sh"
sd_stage_local_artifacts && trap 'sd_cleanup_local_artifacts' EXIT INT TERM

STAGE="${1:-all}"
case "$STAGE" in
    build|run|all) ;;
    *) echo "usage: $0 [build|run|all]" >&2; exit 2 ;;
esac

build_image() {
    trace_run docker build --target sample --build-arg https_proxy \
              --build-arg http_proxy \
              --build-arg SGX_MODE=$SGX_MODE \
              --build-arg SAMPLE_NAME=$SAMPLE_NAME \
              --build-arg QUOTE_PROVIDER="$QUOTE_PROVIDER" \
              --build-arg COLLATERAL_PROVIDER="$COLLATERAL_PROVIDER" \
              --build-arg INSTALL_DCAP_QPL="$INSTALL_DCAP_QPL" \
              --build-arg INSTALL_DCAP_QVL="$INSTALL_DCAP_QVL" \
              --build-arg SAMPLE_EXTRA_RUNTIME_PACKAGES="$SAMPLE_EXTRA_RUNTIME_PACKAGES" \
              $SGX_VERSION_ARG \
              -t sgx_sample -f ./Dockerfile ./
}

run_sample() {
    # Collect the docker run flags from helpers (helpers/sample-defaults.sh); each is empty when it
    # does not apply -- under SIM all three collapse to nothing -- so one invocation covers SIM and HW.
    DEV_SGX_ENCLAVE_ARGS=$(sd_enclave_flags)      # --device /dev/sgx_enclave + --group-add sgx (HW only)
    DEV_SGX_PROVISION_ARGS=$(sd_provision_flags)  # --device /dev/sgx_provision + --group-add sgx_prv (in-process DCAP only)
    AESM_ARGS=$(sd_aesm_flags)                    # -v AESM socket mount + --env SGX_AESM_ADDR (USE_AESM=1)
    TTY_FLAG=$(sd_tty_flags)                      # -t only on a real terminal

    echo "----- host setup complete; container output begins (sgx_sample) -----" >&2
    rc=0
    trace_run docker run --rm --name sgx_sample --env http_proxy --env https_proxy \
        $DEV_SGX_ENCLAVE_ARGS $DEV_SGX_PROVISION_ARGS $AESM_ARGS -i $TTY_FLAG sgx_sample || rc=$?
    echo "----- container output ended (rc=$rc) -----" >&2
    return "$rc"
}

case "$STAGE" in
    build) build_image ;;
    run)   run_sample ;;
    all)   build_image; run_sample ;;
esac
