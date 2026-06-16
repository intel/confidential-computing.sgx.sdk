#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../buildenv.mk

IPP_SOURCE = ipp-crypto
INSTALL_DIR=install
IPP_CONFIG = -Bbuild -DCMAKE_VERBOSE_MAKEFILE=on -DCMAKE_INSTALL_PREFIX=./$(INSTALL_DIR)
# Turn off the build of Crypto Multi Buffer library
IPP_CONFIG += -DNO_CRYPTO_MB:BOOL=TRUE
# Ignore the CMAKE C/C++ compiler check to avoid conflicts with mitigation options
IPP_CONFIG += -DCMAKE_C_COMPILER_WORKS=TRUE -DCMAKE_CXX_COMPILER_WORKS=TRUE 
ARCH = intel64
IPP_CONFIG += -DARCH=$(ARCH)

ENC_FLAGS = $(patsubst -fpie, -fpic, $(ENCLAVE_CFLAGS))
# ipp-crypto requires system header files
ENC_CFLAGS = $(patsubst -nostdinc, , $(ENC_FLAGS))
ENC_CXXFLAGS = $(ENC_CFLAGS)

IPP_CONFIG += -DCMAKE_C_FLAGS="$(ENC_CFLAGS)"
IPP_CONFIG += -DCMAKE_CXX_FLAGS="$(ENC_CXXFLAGS)"

IPP_CONFIG += -DSGX_PROGRAM_SEARCH_PATH="$(EXT_BINUTILS_DIR)"
# enables all FIPS-compliance changes in ipp-crypto
IPP_CONFIG += -DIPPCP_FIPS_MODE=on  -DFIPS_CUSTOM_IPPCP_API_HEADER=$(CURDIR)/inc/sgx_ippcp.h

SUB_DIR = no_mitigation
ifeq ($(MITIGATION-CVE-2020-0551), LOAD)
	SUB_DIR = cve_2020_0551_load
	PRE_CONFIG= ASM_NASM="$(CURDIR)/../../build-scripts/sgx-asm-pp.py --assembler=nasm --MITIGATION-CVE-2020-0551=LOAD"
else ifeq ($(MITIGATION-CVE-2020-0551), CF)
	SUB_DIR = cve_2020_0551_cf
	PRE_CONFIG= ASM_NASM="$(CURDIR)/../../build-scripts/sgx-asm-pp.py --assembler=nasm --MITIGATION-CVE-2020-0551=CF"
endif
OUT_DIR = lib/linux/$(ARCH)/$(SUB_DIR)/

CHECK_SOURCE :=
# For reproducibility build in docker, the code should be
# prepared before build. So skip the code check to avoid
# triggering network request
ifneq ($(origin NIX_STORE), environment)
CHECK_SOURCE:= $(IPP_SOURCE)/build
endif

.PHONY: all build_ipp disp
all: build_ipp
	# Copy the library, header files and license to the target folder
	$(MKDIR) $(OUT_DIR)
	$(CP) $(IPP_SOURCE)/$(INSTALL_DIR)/lib/intel64/libippcp.a $(OUT_DIR)
	$(CP) $(IPP_SOURCE)/$(INSTALL_DIR)/include/* ./inc/
	patch $(IPP_SOURCE)/$(INSTALL_DIR)/include/ippcp.h -i ./inc/ippcp21u12.patch -o ./inc/ippcp.h
	$(MKDIR) license
	$(CP) $(IPP_SOURCE)/LICENSE ./license/

build_ipp: $(CHECK_SOURCE)
	cd $(IPP_SOURCE) && $(PRE_CONFIG) cmake CMakeLists.txt $(IPP_CONFIG) && cd build && make ippcp_s && make install

$(IPP_SOURCE)/build:
ifeq ($(shell git rev-parse --is-inside-work-tree), true)
	git submodule update -f --init --recursive --remote -- $(IPP_SOURCE)
else
	$(RM) -rf $(IPP_SOURCE)
	git clone -b cryptography-primitives_2_2_0 https://github.com/intel/cryptography-primitives --depth 1 $(IPP_SOURCE)
endif
	cd $(IPP_SOURCE) && git apply ../0001-Cryptography-Primitives-for-SGX.patch
	mkdir -p $(IPP_SOURCE)/build $(IPP_SOURCE)/$(INSTALL_DIR)

disp: all
	@echo Generating SGX dispatcher code
	cd $(IPP_SOURCE)/tools/ipp_custom_library_tool_python && \
		awk -F, '/IPPAPI\(/ {print $$2}' $(CURDIR)/inc/ippcp.h | awk '{print $$1}' > functions.txt && \
		python3 clt.py -g -p ./ -ff functions.txt -arch intel64 -d sse42 avx2 avx512ifma -root ../../install --prefix sgx_disp_ && \
		./build_custom_library_intel64.sh 2> /dev/null && \
		$(CP) custom_dispatcher/intel64/*.c $(CURDIR)/../../sdk/tlibcrypto/ipp/ipp_disp/intel64/

.PHONY: clean
clean:
	$(RM) -rf $(IPP_SOURCE)/build/* $(IPP_SOURCE)/$(INSTALL_DIR)/*
