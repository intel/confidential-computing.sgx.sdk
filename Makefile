#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include buildenv.mk

.PHONY: all tips preparation dcap_prebuilts sdk_no_mitigation sdk clean rebuild servtd_attest servtd_attest_preparation ipp sdk_install_pkg_no_mitigation sdk_install_pkg sdk_install_pkg_from_source

all: tips

tips:
	@echo "Tips:"
	@echo "     This \"make\" command will show tips only and make nothing."
	@echo "     1. If you want to build Intel(R) SGX SDK with default configuration (with all mitigation modes for CVE-2020-0551), please take the following steps:"
	@echo "        1) ensure that you have installed required tools described in README.md in same directory"
	@echo "        2) enter the command: \"make sdk\"    Note: see README.md for supported build flavors (\$$USE_OPT_LIBS, \$$DEBUG); default is IPP (pre-built), release mode"
	@echo "     2. If you want to build  Intel(R) SGX PSW enclave runtime components (uRTS, enclave_common libs), please take the following steps:"
	@echo "        1) ensure that you have installed required tools described in README.md in same directory"
	@echo "        2) enter the command: \"make enclave_runtime\""
	@echo "     3. If you want to build other targets, please also follow README.md in same directory"
	@echo "     ----------------------------------------------------------------"
	@echo "     Prerequisite: run \"make preparation\" to prepare the source code before building other targets."
	@echo "     ----------------------------------------------------------------"	
	@echo "     Other targets:"
	@echo "        1) make release           : build all install packages for release (SDK and PSW components). Packaging type (DEB/RPM) is auto-detected (override via \$$RELEASE_PKG_FORMAT)"
	@echo "        2) make sdk_no_mitigation : build Intel(R) SGX SDK without any mitigation for CVE-2020-0551"
	@echo "        3) make servtd_attest     : build Intel(R) SGX SDK components required for Service TD Attestation support (TDX-specific, non-enclave build flavor); requires \"servtd_attest_preparation\" to be run first"
	@echo "        4) make ipp               : build Intel(R) IPP Crypto library for Intel(R) SGX SDK"
	@echo "        5) make [deb|rpm]         : build all the deb/rpm packages (libsgx-enclave-common, libsgx-urts, libsgx-headers, sgx-sdk(RPM-only))"
	@echo "        6) make sdk_install_pkg_no_mitigation : generate Intel(R) SGX SDK install package without mitigation for CVE-2020-0551"
	@echo "        7) make sdk_install_pkg               : generate Intel(R) SGX SDK install package with all mitigation modes for CVE-2020-0551"
	@echo "        8) make sdk_install_pkg_from_source   : generate Intel(R) SGX SDK install package from source code including IPP Crypto and SGXSSL"
	@echo "        9) make [deb|rpm]_enclave_runtime     : build the deb/rpm packages for enclave runtime components (uRTS, enclave_common libs)"
	@echo "       10) make [deb|rpm]_libsgx_headers_pkg  : build the deb/rpm packages for libsgx-headers development package"
	@echo "     ----------------------------------------------------------------"

USE_PREBUILT_IPP ?= yes

preparation: dcap_prebuilts
# As SDK build needs to clone and patch openmp, we cannot support the mode that download the source from github as zip.
# Only enable the download from git
	git submodule update --init --recursive
	cd external/openmp/openmp_code && git apply ../0001-Enable-OpenMP-in-SGX.patch >/dev/null 2>&1 ||  git apply ../0001-Enable-OpenMP-in-SGX.patch --check -R

	# TODO refactor to remove duplication with the ./external/protobuf/Makefile.
	# This Makefile should call ./external/protobuf/Makefile targets instead.
	# If you are adding a new patch over this one, write your patch's name to .sgx_patched
	@if ! grep -q "sgx_protobuf" external/protobuf/protobuf_code/.sgx_patched 2>/dev/null; then \
		cd external/protobuf/protobuf_code && \
		git apply ../sgx_protobuf.patch >/dev/null 2>&1 || git apply ../sgx_protobuf.patch --check -R && \
		git submodule update --init --recursive; \
	fi
	# If you are adding a new patch over this one, write your patch's name to .sgx_patched
	@if ! grep -q "sgx_abseil" external/protobuf/abseil-cpp/.sgx_patched 2>/dev/null; then \
		cd external/protobuf/abseil-cpp && \
		git apply ../sgx_abseil.patch >/dev/null 2>&1 || git apply ../sgx_abseil.patch --check -R; \
	fi
	./external/sgx-emm/create_symlink.sh
	cd external/cbor && cp -r libcbor sgx_libcbor
	cd external/cbor/libcbor && git apply ../raw_cbor.patch >/dev/null 2>&1 || git apply ../raw_cbor.patch --check -R
	cd external/cbor/sgx_libcbor && git apply ../sgx_cbor.patch >/dev/null 2>&1 || git apply ../sgx_cbor.patch --check -R
	cd external/ippcp_internal/ipp-crypto && git apply ../0001-Cryptography-Primitives-for-SGX.patch > /dev/null 2>&1 || git apply ../0001-Cryptography-Primitives-for-SGX.patch --check -R
	cd external/ippcp_internal/ipp-crypto && mkdir -p build
	cd external/libcxxrt/libcxxrt_code && git apply ../sgx_libcxxrt.patch >/dev/null 2>&1 || git apply ../sgx_libcxxrt.patch --check -R
ifeq ($(USE_PREBUILT_IPP), yes)
	./build_infrastructure/download_prebuilt.sh
	@echo "Preparation finished. NOTE: prebuilt IPP Crypto libraries downloaded."
	@echo "If you want to compile IPP Crypto libraries from source, run \"make preparation USE_PREBUILT_IPP=no\""
else
	./build_infrastructure/download_prebuilt.sh no_prebuilt_ipp
	@echo "Preparation finished. NOTE: IPP Crypto libraries need to be built from source. Run 'make ipp' to build them or use one of the '*_from_source' targets."
endif

dcap_prebuilts:
	./build_infrastructure/download_prebuilt_dcap.sh

sdk_no_mitigation:
	$(MAKE) -C sdk/ USE_OPT_LIBS=$(USE_OPT_LIBS)

sdk:
	$(MAKE) -C sdk/ clean MITIGATION-CVE-2020-0551=LOAD
	$(MAKE) -C sdk/ MODE=$(MODE) MITIGATION-CVE-2020-0551=LOAD
	$(MAKE) -C sdk/ clean MITIGATION-CVE-2020-0551=CF
	$(MAKE) -C sdk/ MODE=$(MODE) MITIGATION-CVE-2020-0551=CF
	$(MAKE) -C sdk/ clean
	$(MAKE) -C sdk/ MODE=$(MODE)

servtd_attest:
	@test -L common/inc/sgx_mm.h \
		&& test -f external/libcxxrt/libcxxrt_code/src/sgx_disable_print.h || \
		{ echo "Error: Please run 'make servtd_attest_preparation' first"; exit 1; }
	$(MAKE) -C sdk/ servtd_attest SERVTD_ATTEST=1

servtd_attest_preparation:
# Only enable the download from git
	git submodule update --init --recursive external/sgx-emm/emm_src external/libcxxrt/libcxxrt_code
	./external/sgx-emm/create_symlink.sh
	cd external/libcxxrt/libcxxrt_code && (git apply ../sgx_libcxxrt.patch >/dev/null 2>&1 || git apply ../sgx_libcxxrt.patch --check -R)

ipp:
	@command -v nasm >/dev/null 2>&1 || (echo "nasm not found, please install nasm" && exit 1)
	$(MAKE) -C external/ippcp_internal/ clean
	$(MAKE) -C external/ippcp_internal/ MITIGATION-CVE-2020-0551=LOAD
	$(MAKE) -C external/ippcp_internal/ clean
	$(MAKE) -C external/ippcp_internal/ MITIGATION-CVE-2020-0551=CF
	$(MAKE) -C external/ippcp_internal/ clean
	$(MAKE) -C external/ippcp_internal/

# Generate SE SDK Install package
sdk_install_pkg_no_mitigation: sdk_no_mitigation
	SDK_VERSION="$(SDK_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/bin/build-installpkg.sh sdk

sdk_install_pkg: sdk
	SDK_VERSION="$(SDK_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/bin/build-installpkg.sh sdk cve-2020-0551

sdk_install_pkg_from_source:
	$(MAKE) ipp
	$(MAKE) sdk
	SDK_VERSION="$(SDK_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/bin/build-installpkg.sh sdk cve-2020-0551

.PHONY: enclave_runtime
enclave_runtime:
	$(MAKE) -C enclave_runtime all

.PHONY: deb_enclave_runtime
deb_enclave_runtime:
	$(MAKE) -C enclave_runtime deb
	
.PHONY: deb_libsgx_headers_pkg
deb_libsgx_headers_pkg:
	SDK_VERSION="$(SDK_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/deb/libsgx-headers/build.sh

# All "PSW" DEBs (urts, enclave_common, libsgx-headers), alias for 'make deb' at this time
# Note: the libsgx-headers package is technically part of SDK but it has historically been treated as a PSW component for packaging purposes in the SGX repo, so preserving it here.
.PHONY: deb_psw_pkg
deb_psw_pkg: deb_enclave_runtime deb_libsgx_headers_pkg

.PHONY: deb
deb: deb_enclave_runtime deb_libsgx_headers_pkg

.PHONY: rpm_enclave_runtime
rpm_enclave_runtime:
	$(MAKE) -C enclave_runtime rpm

.PHONY: rpm_sdk_pkg
rpm_sdk_pkg: sdk
	SDK_VERSION="$(SDK_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/rpm/sdk/build.sh

.PHONY: rpm_libsgx_headers_pkg
rpm_libsgx_headers_pkg:
	SDK_VERSION="$(SDK_VERSION)" PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/rpm/libsgx-headers/build.sh

# All "PSW" RPMs (urts, enclave_common, libsgx-headers), = all except the SDK package
# Note: the libsgx-headers package is technically part of SDK but it has historically been treated as a PSW component for packaging purposes in the SGX repo, so preserving it here.
.PHONY: rpm_psw_pkg
rpm_psw_pkg: rpm_enclave_runtime rpm_libsgx_headers_pkg

# All RPMs
.PHONY: rpm
rpm: rpm_enclave_runtime rpm_libsgx_headers_pkg rpm_sdk_pkg

.PHONY: deb_local_repo rpm_local_repo
deb_local_repo rpm_local_repo:
	@echo "ERROR: $@ target is not supported in this repo at the moment."
	@echo "For holistic packaging, you need to consume this repo vendored into .sgx repo:"
	@echo "https://github.com/intel/confidential-computing.sgx and its targets of the same name"
	@exit 1

clean:
	@$(MAKE) -C sdk/                               clean
	@$(MAKE) -C enclave_runtime/                   clean
	@$(RM)   -r $(ROOT_DIR)/build
	@$(RM)   -r $(PKG_OUT_ROOT_DIR)/bin/install-sgx-*.bin*.withLicense
	@$(RM)   -r $(PKG_OUT_ROOT_DIR)/bin/sgx_linux*.bin
	PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/deb/libsgx-enclave-common/clean.sh
	PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/deb/libsgx-urts/clean.sh
	PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/deb/libsgx-headers/clean.sh
	PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/rpm/libsgx-enclave-common/clean.sh
	PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/rpm/libsgx-urts/clean.sh
	PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/rpm/libsgx-headers/clean.sh
	PKG_OUT_ROOT_DIR="$(PKG_OUT_ROOT_DIR)" ./build_infrastructure/linux/installer/rpm/sdk/clean.sh
	$(MAKE) -C external/ippcp_internal/ clean

# A "catch all" target to build the SDK and enclave runtime components (incl. packaging) in their default flavors.

.PHONY: _release_deps
_release_deps: sdk_install_pkg $(RELEASE_PKG_FORMAT)_psw_pkg | preparation

.PHONY: release
release: preparation _release_deps
	@set -eu; \
	if [ -t 1 ]; then C_OK='\033[1;32m'; C_RST='\033[0m'; else C_OK=''; C_RST=''; fi; \
	ext='$(RELEASE_PKG_FORMAT)'; \
	if [ "$$ext" = "deb" ]; then sep='_'; dev='dev'; else sep='-'; dev='devel'; fi; \
	cwd="$$(pwd)"; \
	printf "%b\n" "$${C_OK}Release build completed successfully.$${C_RST}"; \
	echo "Artifact root: $(PKG_OUT_ROOT_DIR)"; \
	echo "1) SDK installer (.bin):"; \
	ls -1 "$(PKG_OUT_ROOT_DIR)"/bin/sgx_linux_*_sdk_*.bin | sed "s|^$${cwd}/||; s/^/    * /"; \
	echo "2) PSW package artifacts (format: $(RELEASE_PKG_FORMAT)):"; \
	echo "  - Regular packages:"; \
	find "$(PKG_OUT_ROOT_DIR)/$$ext" -type f -name "libsgx-enclave-common$$sep[0-9]*.$$ext" 2>/dev/null | sort | sed "s|^$${cwd}/||; s/^/    * /"; \
	find "$(PKG_OUT_ROOT_DIR)/$$ext" -type f -name "libsgx-urts$$sep[0-9]*.$$ext" 2>/dev/null | sort | sed "s|^$${cwd}/||; s/^/    * /"; \
	echo "  - Dev packages:"; \
	find "$(PKG_OUT_ROOT_DIR)/$$ext" -type f -name "libsgx-enclave-common-$$dev$$sep[0-9]*.$$ext" 2>/dev/null | sort | sed "s|^$${cwd}/||; s/^/    * /"; \
	find "$(PKG_OUT_ROOT_DIR)/$$ext" -type f -name "libsgx-headers$$sep[0-9]*.$$ext" 2>/dev/null | sort | sed "s|^$${cwd}/||; s/^/    * /";

rebuild:
	$(MAKE) clean
	$(MAKE) all

.PHONY: distclean
distclean:
	$(MAKE) clean
	# Cleanup
	$(RM) -r 'Intel redistributable binary.txt' Master_EULA_for_Intel_Sw_Development_Products.pdf redist.txt
	find external/ippcp_internal/inc/ -name '*.h' ! -name 'sgx_ippcp.h' -delete
	$(RM) -rf external/ippcp_internal/lib/ external/ippcp_internal/license
	$(RM) -rf external/toolset
	$(RM) -rf prebuilt
	git submodule deinit  --all -f
	$(RM) -rf external/openmp/openmp_code external/protobuf/protobuf_code
	git submodule update --init --recursive
