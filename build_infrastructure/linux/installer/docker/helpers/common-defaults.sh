#!/bin/sh
#
# Copyright(c) 2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Shared utilities SOURCED by the docker run scripts (directly by build_and_run_aesm_docker.sh,
# and transitively via helpers/sample-defaults.sh): small docker/group helpers plus optional
# local-artifact staging. The docker build/run invocation stays in each calling script.
#
# Resolved outputs (in the sourcing shell): SGX_VERSION_ARG,
# SGX_OVERRIDE_SDK_INSTALLER_PATH, SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH.
# Provides: sd_die(), trace_run(), compose_cmd(), sd_gid(), sd_group_add_flags(),
# sd_export_gid(), sd_stage_local_artifacts(), sd_cleanup_local_artifacts().

# Abort the sourcing script.
sd_die() { printf 'ERROR: %s\n' "$*" >&2; return 1 2>/dev/null || exit 1; }

# Print and run a command (lightweight tracing, no shell xtrace noise).
trace_run() {
    printf '+ %s\n' "$*" >&2
    "$@"
}

# Run docker compose, supporting both v2 ("docker compose") and v1 ("docker-compose").
compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        trace_run docker compose "$@"
    elif docker-compose version >/dev/null 2>&1; then
        trace_run docker-compose "$@"
    else
        echo "ERROR: neither 'docker compose' nor 'docker-compose' is available on PATH." >&2
        return 127
    fi
}

# Echo a host group's numeric GID (empty if the group is absent). The host "sgx"/"sgx_prv" groups
# are created by systemd / Intel packages and their GIDs are not stable across hosts, so callers
# resolve them at run time to map /dev/sgx_* access into the containers.
sd_gid() { getent group "$1" 2>/dev/null | cut -d: -f3; }

# `docker run` form: echo "--group-add <gid>" for each named host group that exists, skipping
# absent ones (a missing group means a world-accessible device node, so no membership needed).
# Usage (unquoted, to word-split into separate flags): docker run $(sd_group_add_flags sgx sgx_prv)
sd_group_add_flags() {
    sd_flags=''
    for sd_g in "$@"; do
        sd_v=$(sd_gid "$sd_g")
        [ -n "$sd_v" ] && sd_flags="$sd_flags --group-add $sd_v"
    done
    printf '%s' "${sd_flags# }"
}

# docker compose form (symmetric to sd_group_add_flags): resolve a host group's GID into a named,
# exported env var that the compose yml references in group_add (the yml supplies the nogroup
# fallback when the var is empty). Usage: sd_export_gid SGX_GID sgx
sd_export_gid() {
    sd_val=$(sd_gid "$2")
    eval "$1=\$sd_val"
    export "$1"
}

# --- Optional release pin ----------------------------------------------------------------------
# SGX_VERSION pins the whole stack to one 01.org release; empty = rolling 'latest'. See README.md.
case "$SGX_VERSION" in
    *[!0-9.]*|.*|*.|*..*) sd_die "invalid SGX_VERSION='$SGX_VERSION' (expected digits and dots, e.g. 2.29)" || return $? ;;
esac
SGX_VERSION_ARG=${SGX_VERSION:+--build-arg SGX_VERSION=$SGX_VERSION}

# --- Optional local SDK/repo artifacts ---------------------------------------------------------
# Host paths to an SDK installer .bin / a sgx_debian_local_repo.tgz; empty keeps the 01.org default.
SGX_OVERRIDE_SDK_INSTALLER_PATH="${SGX_OVERRIDE_SDK_INSTALLER_PATH:-}"
SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH="${SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH:-}"

# Stage the optional local artifacts into _sgx_local_artifacts/ (tracked dir with a .keep sentinel)
# for the Dockerfile COPY. Clear stale files first, then copy. Call once knobs are validated.
sd_stage_local_artifacts() {
    mkdir -p ./_sgx_local_artifacts
    find ./_sgx_local_artifacts -not -name '.keep' -not -type d -delete 2>/dev/null || true
    [ -n "$SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH" ] && cp -- "$SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH" ./_sgx_local_artifacts/repo.tgz
    [ -n "$SGX_OVERRIDE_SDK_INSTALLER_PATH" ]  && cp -- "$SGX_OVERRIDE_SDK_INSTALLER_PATH"  ./_sgx_local_artifacts/sdk_installer.bin
    return 0
}

# Remove staged artifacts on exit (register via: trap 'sd_cleanup_local_artifacts' EXIT INT TERM).
sd_cleanup_local_artifacts() {
    find ./_sgx_local_artifacts -not -name '.keep' -not -type d -delete 2>/dev/null || true
}
