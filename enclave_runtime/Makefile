#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This Makefile will compile enclave_runtime components, including:
#  - enclave_common static and dynamic library (libsgx_enclave_common.a and libsgx_enclave_common.so)
#  - uRTS dynamic library (libsgx_urts.so and libsgx_urts_internal.so)
#    Note: uRTS depends on enclave_common; both link se_wrapper (libwrapper.a from ../common/se_wrapper/)
#
include ../buildenv.mk

.PHONY: all urts enclave_common clean rebuild

all: urts

# Note: uRTS has internal dependency on enclave_common; this declaration is just for clarity
urts: enclave_common
	$(MAKE) -C urts/linux/

enclave_common:
	$(MAKE) -C enclave_common/

clean:
	$(MAKE) -C urts/linux          clean
	$(MAKE) -C enclave_common      clean

rebuild:
	$(MAKE) clean
	$(MAKE) all


.PHONY: deb_libsgx_enclave_common
deb_libsgx_enclave_common: enclave_common
	ENCLAVE_RUNTIME_VERSION="$(ENCLAVE_RUNTIME_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" $(ROOT_DIR)/build_infrastructure/linux/installer/deb/libsgx-enclave-common/build.sh

.PHONY: rpm_libsgx_enclave_common
rpm_libsgx_enclave_common: enclave_common
	ENCLAVE_RUNTIME_VERSION="$(ENCLAVE_RUNTIME_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" $(ROOT_DIR)/build_infrastructure/linux/installer/rpm/libsgx-enclave-common/build.sh

.PHONY: deb_libsgx_urts
deb_libsgx_urts: urts
	ENCLAVE_RUNTIME_VERSION="$(ENCLAVE_RUNTIME_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" $(ROOT_DIR)/build_infrastructure/linux/installer/deb/libsgx-urts/build.sh

.PHONY: rpm_libsgx_urts
rpm_libsgx_urts: urts
	ENCLAVE_RUNTIME_VERSION="$(ENCLAVE_RUNTIME_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" $(ROOT_DIR)/build_infrastructure/linux/installer/rpm/libsgx-urts/build.sh

.PHONY: deb
deb: deb_libsgx_enclave_common deb_libsgx_urts

.PHONY: rpm
rpm: rpm_libsgx_enclave_common rpm_libsgx_urts
