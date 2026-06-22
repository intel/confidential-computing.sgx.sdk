# Copyright(c) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

FROM quay.io/centos/centos:stream9 AS qgs-builder

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
RUN sh -c 'echo yes | /linux-sgx/linux/installer/bin/sgx_linux_x64_sdk_*.bin'

WORKDIR /linux-sgx
ENV BUILD_PLATFORM="docker"
ENV SGX_SDK=/opt/intel/sgxsdk
RUN make rpm_local_repo


FROM quay.io/centos/centos:stream9 AS qgs

WORKDIR /installer

COPY --from=qgs-builder /linux-sgx/linux/installer/rpm/sgx_rpm_local_repo/ .
# Pin the local repo above appstream (default priority 99) so tdx-qgs and the SGX
# libs resolve from here, not CentOS appstream (whose sgx-libs collides with the
# locally built libsgx-dcap-default-qpl over shared .so files).
RUN printf '[installer]\nname=installer\nbaseurl=file:///installer\nenabled=1\ngpgcheck=0\npriority=1\n' \
    > /etc/yum.repos.d/installer.repo
RUN dnf -y install --setopt=install_weak_deps=False tdx-qgs \
    libsgx-dcap-default-qpl
RUN mkdir -p /var/run/tdx-qgs/
RUN sed -i "s/localhost:8081/host.docker.internal:8081/" /etc/sgx_default_qcnl.conf && \
    sed -i 's/"use_secure_cert": true/"use_secure_cert": false/' /etc/sgx_default_qcnl.conf && \
    sed -i "s/port = 4050//" /etc/qgs.conf


WORKDIR /opt/intel/tdx-qgs
CMD ["./qgs", "--no-daemon"]
