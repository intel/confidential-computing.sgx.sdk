# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#


FROM quay.io/centos/centos:stream9 AS builder

RUN dnf -y install 'dnf-command(config-manager)'
RUN dnf config-manager --set-enabled crb
RUN dnf -y groupinstall 'Development Tools'
RUN dnf -y install epel-release epel-next-release ocaml ocaml-ocamlbuild wget python openssl-devel libcurl-devel \
        protobuf-devel cmake createrepo yum-utils dos2unix pkgconf boost-devel \
        protobuf-lite-devel perl

# We assume this docker file is invoked with root at the top of linux-sgx repo, see shell scripts for example.
WORKDIR /linux-sgx
COPY . .
RUN make sdk_install_pkg_no_mitigation

WORKDIR /opt/intel
RUN sh -c 'echo yes | /linux-sgx/build_infrastructure/linux/installer/bin/sgx_linux_x64_sdk_*.bin'

WORKDIR /linux-sgx
ENV BUILD_PLATFORM="docker"
ENV SGX_SDK=/opt/intel/sgxsdk
RUN make FLATTEN_PKG_OUT_DIR=1 rpm


FROM quay.io/centos/centos:stream9 AS sample_rpm
RUN dnf -y install --setopt=install_weak_deps=False \
    gcc-c++ \
    libcurl-devel \
    openssl-devel \
    protobuf-devel \
    make

WORKDIR /rpms

# This repo does not produce a local RPM repository; it produces package artifacts.
# Copy all built RPMs from the builder stage and install required packages manually.
COPY --from=builder /linux-sgx/build_infrastructure/linux/installer/rpm/*.rpm ./
RUN dnf -y install --setopt=install_weak_deps=False ./libsgx-headers*.rpm
RUN dnf -y install --setopt=install_weak_deps=False ./libsgx-enclave-common*.rpm
RUN dnf -y install --setopt=install_weak_deps=False ./libsgx-urts*.rpm

WORKDIR /opt/intel
COPY --from=builder /linux-sgx/build_infrastructure/linux/installer/bin/*.bin ./
RUN sh -c 'echo yes | ./sgx_linux_x64_sdk_*.bin'

# SAMPLE_NAME selects which SGX SDK sample under SampleCode/ to build; defaults to
# SampleEnclave. Override with --build-arg SAMPLE_NAME=<name>. Only installed SDK samples
# are available here; a DCAP sample would instead be COPYed from the builder stage (e.g.
# /linux-sgx/external/dcap_source/SampleCode/<name>) and built like the others.
ARG SAMPLE_NAME=SampleEnclave
WORKDIR /opt/intel/sgxsdk/SampleCode/${SAMPLE_NAME}
RUN SGX_DEBUG=0 SGX_MODE=HW SGX_PRERELEASE=1 make

# Create sgxuser with a home dir so QCNL-using samples can cache collateral under
# $HOME/.dcap-qcnl (harmless for SDK samples, which never load the QCNL).
RUN useradd --create-home --shell /bin/bash sgxuser
USER sgxuser

CMD ["./app"]
