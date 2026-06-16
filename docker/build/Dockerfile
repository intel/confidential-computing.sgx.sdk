# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install  -y \
    autoconf \
    automake \
    build-essential \
    cmake \
    debhelper \
    git \
    libcurl4-openssl-dev \
    libprotobuf-dev \
    libssl-dev \
    libtool \
    lsb-release \
    ocaml \
    ocamlbuild \
    protobuf-compiler \
    python-is-python3 \
    reprepro \
    wget \
    perl \
    unzip \
    pkgconf \
    libboost-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libsystemd0
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# We assume this docker file is invoked with root at the top of linux-sgx repo, see shell scripts for example.
WORKDIR /linux-sgx
COPY . .

RUN make sdk_install_pkg_no_mitigation

WORKDIR /opt/intel
RUN sh -c 'echo yes | /linux-sgx/linux/installer/bin/sgx_linux_x64_sdk_*.bin'

ENV SGX_SDK=/opt/intel/sgxsdk
WORKDIR /linux-sgx

ENV BUILD_PLATFORM="docker"
RUN make deb_local_repo

FROM ubuntu:22.04 AS aesm_deb
ARG INSTALL_DCAP_QPL=0
# PCCS endpoint baked into "pccs_url" in /etc/sgx_default_qcnl.conf when the QPL is installed.
# The package default (localhost:8081) is the aesm container's own loopback and never
# reachable, so it is rewritten to a PCCS on the Docker host. Override --build-arg
# PCCS_HOST_URL=<pccs_url> to target a different provider; see build_compose_run.sh for the
# host/peer-PCCS and Intel-PCS options.
ARG PCCS_HOST_URL=https://host.docker.internal:8081/sgx/certification/v4/
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libprotobuf-dev \
    libssl-dev \
    make

WORKDIR /deb_local_repo

COPY --from=builder /linux-sgx/linux/installer/deb/sgx_debian_local_repo/ ./
RUN echo "deb [trusted=yes arch=amd64] file:///deb_local_repo jammy main">>/etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y libsgx-aesm-quote-ex-plugin && \
    if [ "$INSTALL_DCAP_QPL" = "1" ]; then \
        apt-get install -y libsgx-dcap-default-qpl && \
        # rewrite the QCNL config's pccs_url to PCCS_HOST_URL
        sed -E -i 's#("pccs_url"[[:space:]]*:[[:space:]]*")[^"]*#\1'"$PCCS_HOST_URL"'#' \
            /etc/sgx_default_qcnl.conf; \
    fi

WORKDIR /opt/intel/sgx-aesm-service/aesm/
ENV LD_LIBRARY_PATH=.
CMD ["./aesm_service", "--no-daemon"]


FROM ubuntu:22.04 AS sample_deb
RUN apt-get update && apt-get install -y \
    g++ \
    libcurl4-openssl-dev \
    libprotobuf-dev \
    libssl-dev \
    make

WORKDIR /deb_local_repo

COPY --from=builder /linux-sgx/linux/installer/deb/sgx_debian_local_repo/ ./
RUN echo "deb [trusted=yes arch=amd64] file:///deb_local_repo jammy main">>/etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y libsgx-urts

WORKDIR /opt/intel
COPY --from=builder /linux-sgx/linux/installer/bin/*.bin ./
RUN sh -c 'echo yes | ./sgx_linux_x64_sdk_*.bin'

# SAMPLE_NAME selects which SGX SDK sample under SampleCode/ to build; defaults to
# SampleEnclave. Override with --build-arg SAMPLE_NAME=<name>. Only installed SDK samples
# are available here; a DCAP sample would instead be COPYed from the builder stage (e.g.
# /linux-sgx/external/dcap_source/SampleCode/<name>) and built like the others.
ARG SAMPLE_NAME=SampleEnclave
WORKDIR /opt/intel/sgxsdk/SampleCode/${SAMPLE_NAME}
RUN SGX_DEBUG=0 SGX_MODE=HW SGX_PRERELEASE=1 make

# Create sgxuser WITH a home dir so a QCNL-using sample can cache PCK collateral under $HOME/.dcap-qcnl (harmless for SDK samples, which never load the QCNL).
RUN adduser -q --disabled-password --gecos "" sgxuser
USER sgxuser

CMD ["./app"]
