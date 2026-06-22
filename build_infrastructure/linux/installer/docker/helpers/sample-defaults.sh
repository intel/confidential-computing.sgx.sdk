#!/bin/sh
#
# Copyright(c) 2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Shared sample/attestation defaults resolver. SOURCED (not executed) by the run scripts so the
# sample validation + provider mapping + bad-combo guards live in exactly one place.
#
# See "Customization options" in README.md for the user-facing knob definitions.
#
# Resolved outputs (exported in the sourcing shell): SAMPLE_NAME, SGX_MODE, QUOTE_PROVIDER,
# COLLATERAL_PROVIDER, USE_AESM, INSTALL_DCAP_QPL, INSTALL_DCAP_QVL,
# SAMPLE_EXTRA_RUNTIME_PACKAGES, SGX_VERSION_ARG, SGX_OVERRIDE_SDK_INSTALLER_PATH,
# SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH.
#
# Behavior: callers may pre-set knobs and this resolver applies those values when valid;
# otherwise it picks per-sample defaults. INSTALL_DCAP_QPL is derived from
# COLLATERAL_PROVIDER (0 for 'none', 1 otherwise).
#
# Provides (docker run flag builders, consumed by build_and_run_sample_docker.sh): sd_tty_flags(),
# sd_enclave_flags(), sd_provision_flags(), sd_aesm_flags().

# Shared local-artifact helpers: sd_die(), SGX_VERSION_ARG, the SGX_OVERRIDE_* knobs, and
# sd_stage_local_artifacts()/sd_cleanup_local_artifacts(). Keep this first -- sd_die is used below.
. "$(dirname "$0")/helpers/common-defaults.sh"

# --- 1. Validate SAMPLE_NAME -------------------------------------------------------------------
SAMPLE_NAME="${SAMPLE_NAME:-SampleEnclave}"
SD_VALID_SAMPLES="Cxx11SGXDemo Cxx14SGXDemo Cxx17SGXDemo LocalAttestation PowerTransition \
ProtobufSGXDemo SampleAEXNotify SampleCommonLoader SampleEnclave SampleEnclaveGMIPP \
SampleEnclavePCL SealUnseal Switchless SampleAttestedTLS"
sd_found=0
for sd_s in $SD_VALID_SAMPLES; do
    [ "$sd_s" = "$SAMPLE_NAME" ] && { sd_found=1; break; }
done
[ "$sd_found" = "1" ] || sd_die "unknown SAMPLE_NAME='$SAMPLE_NAME'. Valid: $SD_VALID_SAMPLES" || return $?

# --- 2. Resolve QUOTE_PROVIDER -----------------------------------------------------------------
# Per-sample allowed providers; the FIRST entry is the sample's built-in default. Of the in-scope
# samples only SampleAttestedTLS does attestation/quoting; RemoteAttestation (legacy EPID, dropped
# after sgx_2.27) is kept here so a reinstated copy still resolves. Every other sample is 'none'.
case "$SAMPLE_NAME" in
    SampleAttestedTLS)  sd_allowed="dcap_aesm dcap_in_proc" ;;
    RemoteAttestation)  sd_allowed="aesm_universal" ;;
    *)                  sd_allowed="none" ;;
esac
sd_default=${sd_allowed%% *}
# A caller-suggested default (DEFAULT_QUOTE_PROVIDER) wins only if valid for this sample.
if [ -n "$DEFAULT_QUOTE_PROVIDER" ]; then
    for sd_p in $sd_allowed; do
        [ "$sd_p" = "$DEFAULT_QUOTE_PROVIDER" ] && { sd_default=$DEFAULT_QUOTE_PROVIDER; break; }
    done
fi
QUOTE_PROVIDER="${QUOTE_PROVIDER:-$sd_default}"
# Validate the (possibly overridden) value: known token AND allowed for this sample.
case "$QUOTE_PROVIDER" in
    none|aesm_universal|dcap_in_proc|dcap_aesm) ;;
    *) sd_die "invalid QUOTE_PROVIDER='$QUOTE_PROVIDER' (expected none|aesm_universal|dcap_in_proc|dcap_aesm)" || return $? ;;
esac
sd_ok=0
for sd_p in $sd_allowed; do
    [ "$sd_p" = "$QUOTE_PROVIDER" ] && { sd_ok=1; break; }
done
[ "$sd_ok" = "1" ] || sd_die "QUOTE_PROVIDER='$QUOTE_PROVIDER' is not valid for $SAMPLE_NAME (allowed: $sd_allowed)" || return $?

# --- 3. COLLATERAL_PROVIDER + derived INSTALL_DCAP_QPL ----------------------------------------------
# Default 'none' without quoting, else 'pccs-host'. INSTALL_DCAP_QPL follows: 0 for none, else 1 --
# any quoting flow needs the QPL/QCNL to fetch PCK collateral from a PCCS. See the "Customization
# options" / "Docker build flavors" sections in README.md.
if [ "$QUOTE_PROVIDER" = "none" ]; then
    COLLATERAL_PROVIDER="${COLLATERAL_PROVIDER:-none}"
else
    COLLATERAL_PROVIDER="${COLLATERAL_PROVIDER:-pccs-host}"
fi
case "$COLLATERAL_PROVIDER" in
    none|pcs|pccs-host|pccs-container) ;;
    *) sd_die "invalid COLLATERAL_PROVIDER='$COLLATERAL_PROVIDER' (expected none|pcs|pccs-host|pccs-container)" || return $? ;;
esac
[ "$COLLATERAL_PROVIDER" = "none" ] && INSTALL_DCAP_QPL=0 || INSTALL_DCAP_QPL=1

# --- 4. INSTALL_DCAP_QVL default --------------------------------------------------------------------
# Quote Verification Library: of the in-scope samples only SampleAttestedTLS verifies a peer's quote
# (each enclave checks the other's), so it defaults on there and off everywhere else.
case "$SAMPLE_NAME" in
    SampleAttestedTLS) INSTALL_DCAP_QVL="${INSTALL_DCAP_QVL:-1}" ;;
    *)                 INSTALL_DCAP_QVL="${INSTALL_DCAP_QVL:-0}" ;;
esac

# --- 4b. SAMPLE_EXTRA_RUNTIME_PACKAGES default ------------------------------------------------------
# Extra non-SGX apt packages a sample needs to RUN (a property of its run recipe, not of quoting).
# SampleAttestedTLS launches via `make run', so the runtime image needs `make'; all others default
# empty. See the Dockerfile's SAMPLE_EXTRA_RUNTIME_PACKAGES ARG / README.md.
case "$SAMPLE_NAME" in
    SampleAttestedTLS) SAMPLE_EXTRA_RUNTIME_PACKAGES="${SAMPLE_EXTRA_RUNTIME_PACKAGES:-make}" ;;
    *)                 SAMPLE_EXTRA_RUNTIME_PACKAGES="${SAMPLE_EXTRA_RUNTIME_PACKAGES:-}" ;;
esac

# --- 5. USE_AESM default -----------------------------------------------------------------------
case "$QUOTE_PROVIDER" in
    aesm_universal|dcap_aesm) USE_AESM="${USE_AESM:-1}" ;;
    *)                        USE_AESM="${USE_AESM:-0}" ;;
esac

# --- 6. Reject known-bad combinations ----------------------------------------------------------
SGX_MODE="${SGX_MODE:-HW}"
case "$SGX_MODE" in
    HW|SIM) ;;
    *) sd_die "invalid SGX_MODE='$SGX_MODE' (expected HW|SIM)" || return $? ;;
esac
# Quoting needs a real platform (PCE/QE3, provisioning) -> not available under simulation.
if [ "$QUOTE_PROVIDER" != "none" ] && [ "$SGX_MODE" = "SIM" ]; then
    sd_die "QUOTE_PROVIDER='$QUOTE_PROVIDER' requires SGX_MODE=HW (quoting cannot run under SIM)" || return $?
fi
# Out-of-process providers must have the AESM available.
case "$QUOTE_PROVIDER" in
    aesm_universal|dcap_aesm)
        [ "$USE_AESM" = "1" ] || sd_die "QUOTE_PROVIDER='$QUOTE_PROVIDER' is out-of-process and requires USE_AESM=1" || return $? ;;
esac

# --- Summary -----------------------------------------------------------------------------------
# Echo the resolved choices so the sourcing run script shows what it is about to build/run. Goes to
# stderr to never contaminate a caller's command substitution of the emitted *_ARGS strings.
sd_sdk_src='<default from SGX_VERSION/latest>'
[ -n "$SGX_OVERRIDE_SDK_INSTALLER_PATH" ] && sd_sdk_src='<set>'
sd_repo_src='<default 01.org apt repo>'
[ -n "$SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH" ] && sd_repo_src='<set>'

{
    printf '%s\n' '--- sample-defaults: resolved options ---'
    printf '  %-33s %s\n' \
        'SAMPLE_NAME'                      "$SAMPLE_NAME" \
        'SGX_MODE'                         "$SGX_MODE" \
        'QUOTE_PROVIDER'                   "$QUOTE_PROVIDER" \
        'COLLATERAL_PROVIDER'              "$COLLATERAL_PROVIDER" \
        'USE_AESM'                         "$USE_AESM" \
        'INSTALL_DCAP_QPL'                 "$INSTALL_DCAP_QPL" \
        'INSTALL_DCAP_QVL'                 "$INSTALL_DCAP_QVL" \
        'SAMPLE_EXTRA_RUNTIME_PACKAGES'    "${SAMPLE_EXTRA_RUNTIME_PACKAGES:-<none>}" \
        'SGX_VERSION'                      "${SGX_VERSION:-<rolling latest>}" \
        'SGX_OVERRIDE_SDK_INSTALLER_PATH'  "$sd_sdk_src" \
        'SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH' "$sd_repo_src"
    printf '%s\n' '-----------------------------------------'
} >&2

# --- docker run flag builders (consumed by build_and_run_sample_docker.sh) ---------------------
# Each prints the run flags for one concern and nothing when it does not apply (e.g. all of them
# under SIM), so the run script can issue a single `docker run` with no conditionals of its own.

# Pseudo-TTY: only when attached to a real terminal (docker run -t fails in CI without one). The
# if/fi keeps the function's exit status 0 when stdin/stdout are not a TTY, so the caller's
# `TTY_FLAG=$(sd_tty_flags)` assignment does not trip `set -e`.
sd_tty_flags() { if [ -t 0 ] && [ -t 1 ]; then printf -- '-t'; fi; }

# SGX enclave device + host "sgx" group, HW only. A missing device is left to fail at runtime,
# except in CI where we warn and skip it so a deviceless runner still starts.
sd_enclave_flags() {
    [ "$SGX_MODE" = "HW" ] || return 0
    if [ ! -e /dev/sgx_enclave ] && [ "${GITHUB_ACTIONS:-}" = "true" ]; then
        echo "WARNING: /dev/sgx_enclave is missing in CI; running without device mapping so app can fail at runtime." >&2
    else
        printf -- '--device=/dev/sgx_enclave '
    fi
    sd_group_add_flags sgx
}

# In-process DCAP quoting (QUOTE_PROVIDER=dcap_in_proc) loads PCE/QE3 in the sample, so it needs
# /dev/sgx_provision + the sgx_prv group; out-of-process leaves provisioning to the AESM (nothing here).
sd_provision_flags() {
    [ "$QUOTE_PROVIDER" = "dcap_in_proc" ] || return 0
    if [ -e /dev/sgx_provision ]; then
        printf -- '--device=/dev/sgx_provision '
    elif [ "${GITHUB_ACTIONS:-}" = "true" ]; then
        echo "WARNING: /dev/sgx_provision is missing in CI; running without provisioning device mapping." >&2
    fi
    sd_group_add_flags sgx_prv
}

# External AESM (USE_AESM=1): mount its socket dir at /var/run/aesmd and point SGX_AESM_ADDR there so
# the DCAP loader quotes OUT-OF-PROCESS. AESM_SOCKET_DIR is a named volume (default) or a host path.
sd_aesm_flags() {
    [ "$USE_AESM" = "1" ] || return 0
    echo "INFO: exporting SGX_AESM_ADDR=/var/run/aesmd/aesm.socket into sample container" >&2
    printf -- '-v %s:/var/run/aesmd --env SGX_AESM_ADDR=/var/run/aesmd/aesm.socket' "${AESM_SOCKET_DIR:-aesmd-socket}"
}

