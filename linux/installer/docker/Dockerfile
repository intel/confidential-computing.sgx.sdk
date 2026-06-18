# syntax=docker/dockerfile:1
# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This Dockerfile DOWNLOADS prebuilt SGX packages from the Intel SGX repo on
# 01.org; it never builds the SDK/PSW from source. (Its sibling in the source tree
# at <root>/docker/build/ self-compiles instead.)

# Install prefix for the downloaded SGX SDK; declared before the first FROM to share across stages (each redeclares it bare).
ARG SDK_INSTALL_DIR=/opt/intel

# ===== Stage 1/4: sgxbase -- common base that wires up the Intel SGX apt source =====
FROM ubuntu:22.04 AS sgxbase
# [1.1] Install fetch tools (ca-certificates/gnupg/wget) for the repo key + SDK installer.
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gnupg \
    wget

# [1.2] Stage optional local override artifacts into the build (empty by default).
# _sgx_local_artifacts/ is a transient staging dir (created/removed by the build scripts; empty = none).
# It may hold two optional files that override the live 01.org sources:
#   repo.tgz          -- sgx_debian_local_repo.tgz (replaces the live apt repo)
#   sdk_installer.bin -- sgx_linux_x64_sdk_*.bin   (replaces the downloaded SDK)
COPY _sgx_local_artifacts/ /tmp/sgx_local_artifacts/

# [1.3] Set up the SGX apt repository: default to the live 01.org repo, or a staged local repo.tgz.
RUN if [ ! -f /tmp/sgx_local_artifacts/repo.tgz ]; then \
      # Default: add the live Intel SGX apt repo on 01.org (fetch its signing key).
      mkdir -p /etc/apt/keyrings && \
      wget -qO /etc/apt/keyrings/intel-sgx-deb.asc https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key && \
      . /etc/os-release && \
      echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/intel-sgx-deb.asc] https://download.01.org/intel-sgx/sgx_repo/ubuntu $VERSION_CODENAME main" > /etc/apt/sources.list.d/intel-sgx.list; \
    else \
      # Staged repo.tgz: extract and use it as a local apt repo (trusted=yes, no network/key).
      # Distro codename comes from the base image (VERSION_CODENAME).
      mkdir -p /opt/intel-sgx-local-repo && \
      tar -xzf /tmp/sgx_local_artifacts/repo.tgz -C /opt/intel-sgx-local-repo && \
      . /etc/os-release && \
      repo_release=$(find /opt/intel-sgx-local-repo -type f -path "*/dists/${VERSION_CODENAME}/Release" | head -n1) && \
      [ -n "$repo_release" ] || { echo "ERROR: local repo tgz has no dists/${VERSION_CODENAME}/Release (wrong distro?)" >&2; exit 1; } && \
      repo_root=${repo_release%/dists/${VERSION_CODENAME}/Release} && \
      echo "deb [trusted=yes arch=amd64] file:${repo_root} $VERSION_CODENAME main" > /etc/apt/sources.list.d/intel-sgx.list; \
    fi && \
    apt-get update \
      -o Dir::Etc::sourcelist="sources.list.d/intel-sgx.list" \
      -o Dir::Etc::sourceparts="-" \
      -o APT::Get::List-Cleanup="0"  # scoped to only the new intel-sgx.list (skip re-fetching Ubuntu indices)
# Keep the apt index so child stages install without re-running apt-get update; safe because
# Valid-Until is checked only at update time (not install) and SGX packages are immutable per release.

# [1.4] Optionally pin all Intel SGX packages to one release line (SGX_VERSION).
# Online repo only: Caps libsgx-*/sgx-* to SGX_VERSION.* via an apt pref (prio 1001, allows downgrade); empty = newest. See README.md.
ARG SGX_VERSION=
RUN [ -n "$SGX_VERSION" ] && [ ! -f /tmp/sgx_local_artifacts/repo.tgz ] && \
    printf 'Package: libsgx-* sgx-*\nPin: version %s.*\nPin-Priority: 1001\n' "$SGX_VERSION" \
        > /etc/apt/preferences.d/intel-sgx.pref || true

# ===== Stage 2/4: build_env -- download + install the SDK (sample-independent, cached) =====
FROM sgxbase AS build_env
ARG SDK_INSTALL_DIR
# SGX_VERSION picks the SDK release: empty = latest/linux-latest, else sgx-linux/<version>/distro. See README.md.
ARG SGX_VERSION=
# [2.1] Install the build toolchain (build-essential = make + gcc/g++ + binutils).
# The SDK installer needs `make' (runs the package's `make install INSTALLER_FORMAT=BIN') and
# `objdump' (binutils, to symlink libsgx_urts.so by SONAME); gcc/g++ are then used to build the
# samples in the next stage.
RUN apt-get install -y build-essential

# [2.2] Get the SDK installer (default: download from 01.org, or reuse a staged sdk_installer.bin) and install it under SDK_INSTALL_DIR.
WORKDIR /tmp
RUN . /etc/os-release; \
    if [ ! -f /tmp/sgx_local_artifacts/sdk_installer.bin ]; then \
      # Default: download the SDK .bin from 01.org (SGX_VERSION picks the release line; empty = latest).
      if [ -z "$SGX_VERSION" ]; then base="https://download.01.org/intel-sgx/latest/linux-latest/distro"; \
      else base="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro"; fi; \
      url="${base}/${ID}${VERSION_ID}-server/" && \
      wget -r -l1 -np -nd --accept 'sgx_linux_x64_sdk_*.bin' "$url" && \
      set -- sgx_linux_x64_sdk_*.bin && \
      [ "$#" -eq 1 ] || { echo "ERROR: expected exactly one sgx_linux_x64_sdk_*.bin but got $#: $*" >&2; exit 1; } && \
      sdk_file=/tmp/$1; \
    else \
      sdk_file=/tmp/sgx_local_artifacts/sdk_installer.bin; \
    fi && \
    chmod +x "$sdk_file" && \
    "$sdk_file" --prefix="$SDK_INSTALL_DIR"  # Install; note /tmp leftovers never reach the final image (this stage is only COPY-ed from)

# NOTE: SampleEnclave (and most samples) build with just build-essential + the SDK's bundled
# quoting headers/libs; DCAP samples need extra -dev pkgs. Those go in stage 3, so
# build_env stays sample-independent -- built once, reused across every SAMPLE_NAME/SGX_MODE/etc.
# ===== Stage 3/4: sgx_sample_builder -- build the selected sample + stage its artifacts =====
FROM build_env AS sgx_sample_builder
ARG SDK_INSTALL_DIR
ARG SAMPLE_NAME=SampleEnclave
# SAMPLE_NAME / SGX_MODE / SGX_DEBUG / SGX_PRERELEASE: see README.md (defaults = HW pre-release build).
ARG SGX_DEBUG=0
ARG SGX_MODE=HW
ARG SGX_PRERELEASE=1
# [3.1] Build the selected sample, installing only its extra build deps (kept here, not in build_env,
# so build_env stays sample-independent). apt index is inherited from sgxbase (no apt-get update).
# Source the SDK environment via POSIX `.` (sets SGX_SDK/PATH/LD_LIBRARY_PATH; works under /bin/sh).
WORKDIR ${SDK_INSTALL_DIR}/sgxsdk/SampleCode/${SAMPLE_NAME}
RUN case "${SAMPLE_NAME}" in \
      SampleCommonLoader) apt-get install -y libsgx-enclave-common-dev ;; \
      SampleAttestedTLS) apt-get install -y git libssl-dev libsgx-dcap-ql-dev libsgx-dcap-quote-verify-dev ;; \
    esac && \
    . ${SDK_INSTALL_DIR}/sgxsdk/environment && \
    SGX_DEBUG=${SGX_DEBUG} SGX_MODE=${SGX_MODE} SGX_PRERELEASE=${SGX_PRERELEASE} make

# [3.2] Stage ONLY the runtime artifacts into a clean tree (/opt/sgx-sample), preserving each
# sample's layout so its run recipe still resolves relative paths; the final image COPYs this tree.
# `cp --parents` recreates parent dirs in one copy; build objects/static libs (and SampleAttestedTLS's
# from-source sgxssl checkout) are left behind. Per sample below: which built files to stage and how
# run.sh launches them (paths/layout differ).
RUN mkdir -p /opt/sgx-sample && \
    case "${SAMPLE_NAME}" in \
      SampleAttestedTLS) \
        # 5 binaries + Makefile/sgxenv.mk, launched via `make run' (multi-process).
        cp -a --parents \
          server/host/tls_server_host server/enc/*.signed.so \
          client/host/tls_client_host client/enc/*.signed.so \
          non_enc_client/tls_non_enc_client \
          Makefile sgxenv.mk \
          /opt/sgx-sample/ && \
        printf '%s\n' '#!/bin/sh' 'exec make run' > /opt/sgx-sample/run.sh ;; \
      LocalAttestation) \
        # Binaries in bin/ (app + appinitiator/appresponder + 2 signed enclaves); stage flat, default
        # to single-process ./app (two-process binaries ride along for command overrides).
        cp -a bin/. /opt/sgx-sample/ && \
        printf '%s\n' '#!/bin/sh' 'exec ./app' > /opt/sgx-sample/run.sh ;; \
      SampleCommonLoader) \
        # Single `sample' binary with the enclave embedded as a blob (no separate *.signed.so).
        cp -a sample /opt/sgx-sample/ && \
        printf '%s\n' '#!/bin/sh' 'exec ./sample' > /opt/sgx-sample/run.sh ;; \
      *) \
        # Other samples are a single ./app (+ signed enclave); run it directly.
        cp -a app *.signed.so /opt/sgx-sample/ && \
        printf '%s\n' '#!/bin/sh' 'exec ./app' > /opt/sgx-sample/run.sh ;; \
    esac && \
    chmod +x /opt/sgx-sample/run.sh

# ===== QCNL config generator (sample-independent helper, shared via COPY --from) =====
# Holds gen-qcnl-confs.sh as a here-file. The sample stage copies it in and runs it only when the
# in-process DCAP QPL is installed; QCNL_CONF_PATH then selects which generated config is active.
FROM scratch AS qcnl_tools
COPY <<'EOF' /gen-qcnl-confs.sh
#!/bin/sh
# Derive per-provider QCNL configs from the package default conf -- one sed recipe applied per
# provider (pccs_url + use_secure_cert). Usage: gen-qcnl-confs.sh <default_conf> <out_dir> <pccs_host_url>
set -eu
src=$1; out=$2; host_url=$3
mkdir -p "$out"
emit() {  # <name> <pccs_url> <use_secure_cert>
    sed -E -e 's#("pccs_url"[[:space:]]*:[[:space:]]*")[^"]*#\1'"$2"'#' \
           -e 's#("use_secure_cert"[[:space:]]*:[[:space:]]*)(true|false)#\1'"$3"'#' \
        "$src" > "$out/$1.conf"
}
emit pcs            https://api.trustedservices.intel.com/sgx/certification/v4/  true
emit pccs-host      "$host_url"                                                  false
emit pccs-container https://pccs:8081/sgx/certification/v4/                      false
EOF

# ===== Stage 4/4: sample -- final minimal runtime image for the sample =====
FROM sgxbase AS sample
ARG SDK_INSTALL_DIR
ARG SAMPLE_NAME=SampleEnclave
# Provider/runtime knobs below: full semantics + per-sample defaults in README.md (Build-args +
# Customization options). Notes here flag only build-time specifics not obvious from the name.
# dcap_* share libsgx-dcap-ql; in/out-of-proc differ only by AESM.
ARG QUOTE_PROVIDER=none
# Add the Quote Verification Library.
ARG INSTALL_DCAP_QVL=0
# Add the Quote Provider Library (here only for dcap_in_proc).
ARG INSTALL_DCAP_QPL=0
# Picks which generated qcnl conf QCNL_CONF_PATH targets.
ARG COLLATERAL_PROVIDER=pccs-host
# Baked into the pccs-host conf (package default localhost is unreachable from the container).
ARG PCCS_HOST_URL=https://host.docker.internal:8081/sgx/certification/v4/
# Extra non-SGX pkgs a sample's run.sh needs (e.g. make).
ARG SAMPLE_EXTRA_RUNTIME_PACKAGES=
# QCNL PCK-collateral cache base (QPL only).
ENV XDG_CACHE_HOME=/var/cache/sgx

# Provide the QCNL config generator (used only in the QPL branch below).
COPY --from=qcnl_tools /gen-qcnl-confs.sh /usr/local/bin/gen-qcnl-confs.sh

# [4.1] Install runtime SGX libs + the selected quote/collateral provider.
RUN apt-get install -y libsgx-urts && \
    case "${QUOTE_PROVIDER}" in \
      aesm_universal)            apt-get install -y --no-install-recommends libsgx-quote-ex ;; \
      dcap_in_proc|dcap_aesm)    apt-get install -y libsgx-dcap-ql ;; \
    esac && \
    # extra non-SGX run deps, then the optional quote-verify lib
    if [ -n "$SAMPLE_EXTRA_RUNTIME_PACKAGES" ]; then apt-get install -y $SAMPLE_EXTRA_RUNTIME_PACKAGES; fi && \
    if [ "$INSTALL_DCAP_QVL" = "1" ]; then apt-get install -y libsgx-dcap-quote-verify; fi && \
    # QPL only for in-process DCAP (out-of-process carries it on the AESM):
    if [ "$INSTALL_DCAP_QPL" = "1" ] && [ "$QUOTE_PROVIDER" = "dcap_in_proc" ]; then \
        apt-get install -y libsgx-dcap-default-qpl && \
        # Generate /etc/sgx_qcnl/{pcs,pccs-host,pccs-container}.conf; QCNL_CONF_PATH (set below) selects which one is used.
        sh /usr/local/bin/gen-qcnl-confs.sh /etc/sgx_default_qcnl.conf /etc/sgx_qcnl "$PCCS_HOST_URL" && \
        # QCNL's PCK-collateral cache (see XDG Base Directory spec)
        mkdir -p "$XDG_CACHE_HOME";  \
    fi && \
    rm -rf /var/lib/apt/lists/*

# [4.2] Use a dedicated, self-contained working directory.
WORKDIR /opt/sgx-sample

# [4.3] Copy the staged runtime tree from the builder (single COPY; per-sample layout preserved by [3.2]).
COPY --from=sgx_sample_builder /opt/sgx-sample/ ./

# [4.4] Ship the SDK's *_sim.so libs for SGX_MODE=SIM; distinct sonames coexist with the HW libsgx-urts.
#       Copied unconditionally on purpose -- a few harmless KB keeps one image per mode.
COPY --from=sgx_sample_builder \
     ${SDK_INSTALL_DIR}/sgxsdk/lib64/libsgx_urts_sim.so \
     ${SDK_INSTALL_DIR}/sgxsdk/lib64/libsgx_uae_service_sim.so \
     ${SDK_INSTALL_DIR}/sgxsdk/lib64/libsgx_quote_ex_sim.so \
     /usr/lib/x86_64-linux-gnu/

# [4.5] Create the unprivileged runtime user; SealUnseal writes a sealed blob to its cwd, so chown that dir to it.
RUN adduser -q --disabled-password --gecos "" --no-create-home sgxuser && \
    case "${SAMPLE_NAME}" in \
      SealUnseal) chown sgxuser . ;; \
    esac && \
    if [ -d "$XDG_CACHE_HOME" ]; then chown -R sgxuser "$XDG_CACHE_HOME"; fi
USER sgxuser

# [4.6] Point QCNL (in-process QPL) at the selected per-provider config from [4.1] instead of overwriting the default.
ENV QCNL_CONF_PATH=/etc/sgx_qcnl/${COLLATERAL_PROVIDER}.conf
CMD ["./run.sh"]

# ===== Stage A1: aesm -- auxiliary sidecar image (out-of-process quoting; branches off sgxbase, not after the sample chain) =====
FROM sgxbase AS aesm
# Provider/runtime knobs below: full semantics + per-sample defaults in README.md. Notes here flag
# only build-time specifics not obvious from the name.
# aesm_universal/dcap_aesm add the quote-ex plugin (out-of-proc quoting); else just sgx-aesm-service.
ARG QUOTE_PROVIDER=none
# Add the Quote Provider Library (here only for the out-of-process providers).
ARG INSTALL_DCAP_QPL=0
# Picks which generated qcnl conf QCNL_CONF_PATH targets.
ARG COLLATERAL_PROVIDER=pccs-host
# Baked into the pccs-host conf (package default localhost is unreachable from the container).
ARG PCCS_HOST_URL=https://host.docker.internal:8081/sgx/certification/v4/
# QCNL PCK-collateral cache base (QPL only).
ENV XDG_CACHE_HOME=/var/cache/sgx

# Provide the QCNL config generator (used only in the QPL branch below).
COPY --from=qcnl_tools /gen-qcnl-confs.sh /usr/local/bin/gen-qcnl-confs.sh

# [A1.1] Install the AESM service (+ optional quote-ex plugin / DCAP QPL + QCNL configs).
RUN case "${QUOTE_PROVIDER}" in \
      # libcurl4: AESM's network_service_bundle dlopen()s on some code paths (mostly legacy/EPID-related and therefore unused),
      #           While AESM package doesn't list it as hard dep. and runs w/o it, we install it proactively just in case.
      aesm_universal|dcap_aesm) apt-get install -y libsgx-aesm-quote-ex-plugin libcurl4 ;; \
      *)                        apt-get install -y sgx-aesm-service libcurl4 ;; \
    esac && \
    if [ "$INSTALL_DCAP_QPL" = "1" ]; then \
        case "${QUOTE_PROVIDER}" in aesm_universal|dcap_aesm) \
        apt-get install -y libsgx-dcap-default-qpl && \
        # Generate /etc/sgx_qcnl/{pcs,pccs-host,pccs-container}.conf; QCNL_CONF_PATH (set below) selects which one is used.
        sh /usr/local/bin/gen-qcnl-confs.sh /etc/sgx_default_qcnl.conf /etc/sgx_qcnl "$PCCS_HOST_URL" && \
        # QCNL's PCK-collateral cache (see XDG Base Directory spec)
        mkdir -p "$XDG_CACHE_HOME" ;; \
        esac; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# [A1.2] Set workdir + library path and launch aesm_service.
WORKDIR /opt/intel/sgx-aesm-service/aesm
# Ensures the AESM libraries in this dir are found.
ENV LD_LIBRARY_PATH=.
# Point QCNL at the selected per-provider config from [A1.1] instead of overwriting the default.
ENV QCNL_CONF_PATH=/etc/sgx_qcnl/${COLLATERAL_PROVIDER}.conf
CMD ["./aesm_service", "--no-daemon"]
