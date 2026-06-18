#!/bin/sh
#
# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

# No DEFAULT_QUOTE_PROVIDER here: the compose path can stand up the AESM itself, so a DCAP sample
# defaults to out-of-process dcap_aesm. See "Customization options" in README.md.

# Shared sample/build-arg resolver (SGX_VERSION_ARG + SGX_OVERRIDE_* and more); stage local artifacts; see README.md.
. "$(dirname "$0")/helpers/sample-defaults.sh"
sd_stage_local_artifacts && trap 'sd_cleanup_local_artifacts' EXIT INT TERM

STAGE="${1:-all}"
case "$STAGE" in
    build|run|all) ;;
    *) echo "usage: $0 [build|run|all]" >&2; exit 2 ;;
esac

build_images() {
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

    # Out-of-process quoting (HW + USE_AESM) also needs a separate AESM image; SIM and in-process
    # quoting do not.
    if [ "$SGX_MODE" != "SIM" ] && [ "$USE_AESM" = "1" ]; then
        trace_run docker build --target aesm --build-arg https_proxy \
              --build-arg http_proxy \
                  --build-arg QUOTE_PROVIDER="$QUOTE_PROVIDER" \
                  --build-arg COLLATERAL_PROVIDER="$COLLATERAL_PROVIDER" \
                  --build-arg INSTALL_DCAP_QPL="$INSTALL_DCAP_QPL" \
                  $SGX_VERSION_ARG -t sgx_aesm -f ./Dockerfile ./
    fi
}

# Apply the non-SGX CI fallback to a candidate COMPOSE_PROFILES list ($1): GitHub-hosted runners
# without /dev/sgx_enclave can't run the HW profiles, so substitute a device-free topology (the SIM
# sample, plus a device-less AESM sidecar for out-of-process mode -- smoke-test only, no functional
# quoting/provisioning). Prints the profiles to use: the override, or the unchanged input otherwise.
apply_ci_profile_overrides() {
    [ "${GITHUB_ACTIONS:-}" = "true" ] && [ ! -e /dev/sgx_enclave ] || { printf '%s' "$1"; return 0; }
    [ "$USE_AESM" = "1" ] && ci_profiles=sim-aesm-client,aesm-nodev || ci_profiles=sim
    echo "WARNING: /dev/sgx_enclave is missing in CI; overriding COMPOSE_PROFILES=$ci_profiles" >&2
    printf '%s' "$ci_profiles"
}

run_stack() {
    if [ "$SGX_MODE" = "SIM" ]; then
        # Simulation: no SGX device, host group or AESM -- just the device-free sample ("sim" profile).
        PROFILES=sim
    else
        # Hardware: USE_AESM (derived from QUOTE_PROVIDER) picks the quoting model for DCAP samples;
        # non-quoting samples leave it 0 and ignore it.
        if [ "$USE_AESM" = "1" ]; then
            # Out-of-process (dcap_aesm / aesm_universal): AESM produces the quote, so the sample needs
            # only /dev/sgx_enclave + the sgx group. Profiles "hw,aesm" (sample + AESM service); Compose
            # creates the shared tmpfs "aesmd-socket" volume (declared in docker-compose.yml) on `up`.
            PROFILES=hw,aesm
        else
            # In-process (dcap_in_proc): the sample loads PCE/QE3 itself, so it also needs
            # /dev/sgx_provision + the sgx_prv group and no AESM. Profile "hw-inproc".
            PROFILES=hw-inproc
        fi

        # On non-SGX GitHub-hosted CI, fall back to a device-free profile (see above helper).
        PROFILES=$(apply_ci_profile_overrides "$PROFILES")

        # Resolve dynamic host GIDs for the yml's group_add (not stable across hosts): "sgx"
        # (/dev/sgx_enclave) and "sgx_prv" (/dev/sgx_provision). Missing groups fall back to nogroup.
        sd_export_gid SGX_GID sgx
        sd_export_gid SGX_PRV_GID sgx_prv
        echo "INFO: exporting SGX_GID=${SGX_GID:-<unset>} SGX_PRV_GID=${SGX_PRV_GID:-<unset>}" >&2
    fi

    echo "INFO: COMPOSE_PROFILES=$PROFILES" >&2
    echo "----- host setup complete; compose/service output begins -----" >&2

    rc=0
    COMPOSE_PROFILES=$PROFILES compose_cmd up --abort-on-container-exit || rc=$?
    
    echo "----- compose/service output ended (rc=$rc) -----" >&2
    return "$rc"
}

case "$STAGE" in
    build) build_images ;;
    run)   run_stack ;;
    all)   build_images; run_stack ;;
esac
