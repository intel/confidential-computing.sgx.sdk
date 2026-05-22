#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../../buildenv.mk

C_ENCLAVE_FLAGS = $(ENCLAVE_CFLAGS)
#SGX dnnl will be built with -fpic
C_ENCLAVE_FLAGS := $(subst -fpie,, $(C_ENCLAVE_FLAGS))

CXX_ENCLAVE_FLAGS = $(C_ENCLAVE_FLAGS)
CXX_ENCLAVE_FLAGS := $(subst -nostdinc,, $(CXX_ENCLAVE_FLAGS))
CXX_ENCLAVE_FLAGS += -nostdinc++
CXX_ENCLAVE_FLAGS += -I$(SGX_HEADER_DIR)/libcxx -I$(SGX_HEADER_DIR)/tlibc -I$(SGX_HEADER_DIR)/


DNNL_DIR = dnnl
LIBDNNL = $(DNNL_DIR)/build/src/libdnnl.a
SGX_DNNL_DIR = sgx_dnnl
SGX_DNNL_LIB = $(SGX_DNNL_DIR)/lib
SGX_DNNL_INCLUDE = $(SGX_DNNL_DIR)/include

DNNL_CONFIG = -DCMAKE_BUILD_TYPE=Release
ifdef DEBUG
	DNNL_CONFIG = -DCMAKE_BUILD_TYPE=Debug
endif

DNNL_CONFIG += -DSGX_PROGRAM_SEARCH_PATH="$(EXT_BINUTILS_DIR)"

.PHONY: all
all: $(LIBDNNL) $(SGX_DNNL_LIB) $(SGX_DNNL_INCLUDE)
	@$(CP) $(LIBDNNL) $(SGX_DNNL_LIB)/libsgx_dnnl.a
	@$(CP) $(DNNL_DIR)/include/dnnl.h $(SGX_DNNL_INCLUDE)
	@$(CP) $(DNNL_DIR)/include/dnnl.hpp $(SGX_DNNL_INCLUDE)
	@$(CP) $(DNNL_DIR)/include/mkldnn.hpp $(SGX_DNNL_INCLUDE)
	@$(CP) $(DNNL_DIR)/include/mkldnn_dnnl_mangling.h $(SGX_DNNL_INCLUDE)
	@$(CP) $(DNNL_DIR)/include/dnnl_debug.h $(SGX_DNNL_INCLUDE)
	@$(CP) $(DNNL_DIR)/include/dnnl_types.h $(SGX_DNNL_INCLUDE)
	@$(CP) $(DNNL_DIR)/build/include/dnnl_config.h $(SGX_DNNL_INCLUDE)
	@$(CP) $(DNNL_DIR)/build/include/dnnl_version.h $(SGX_DNNL_INCLUDE)

$(SGX_DNNL_LIB):
	@$(MKDIR) $@

$(SGX_DNNL_INCLUDE):
	@$(MKDIR) $@

$(DNNL_DIR)/build:
	@echo "Checkout dnnl and apply sgx_dnnl patch"
ifeq ($(shell git rev-parse --is-inside-work-tree), true)
	@$(RM) -r $(DNNL_DIR)/*
	git -c submodule.dnnl.update=checkout submodule update -f --init dnnl
	cd $(DNNL_DIR) && git apply ../sgx_dnnl.patch
else
	@$(RM) -r $(DNNL_DIR)
	git clone https://github.com/intel/mkl-dnn.git -b v1.1.1 --depth 1  $(DNNL_DIR)
	cd $(DNNL_DIR) && git apply ../sgx_dnnl.patch
endif
	mkdir -p $(DNNL_DIR)/build

$(LIBDNNL): $(DNNL_DIR)/build
	cd $(DNNL_DIR)/build && cmake -DCMAKE_CXX_ENCLAVE_FLAGS="$(CXX_ENCLAVE_FLAGS)" -DCMAKE_C_ENCLAVE_FLAGS="$(C_ENCLAVE_FLAGS)" $(DNNL_CONFIG) .. && $(MAKE)

.PHONY: clean
clean:
	rm -fr $(DNNL_DIR)/build/* $(SGX_DNNL_DIR)/

.PHONY: rebuild
rebuild:
	$(MAKE) clean
	$(MAKE) all

