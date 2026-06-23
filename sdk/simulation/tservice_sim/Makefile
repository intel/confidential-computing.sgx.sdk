#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

TOP_DIR := ../../..
include $(TOP_DIR)/buildenv.mk

CFLAGS   += -Werror $(ENCLAVE_CFLAGS)
CXXFLAGS += -Werror $(ENCLAVE_CXXFLAGS)

INCLUDE += -I$(COMMON_DIR)            \
           -I$(COMMON_DIR)/inc/tlibc  \
           -I$(SGX_IPP_INC)           \
           -I$(TOP_DIR)/common/inc \
           -I$(TOP_DIR)/common/inc/internal 

TSERVICE_SIM_LIB := libsgx_tservice_sim.a

TSEAL_LIB_DIR := $(LINUX_SDK_DIR)/tseal/linux
TSEAL_LIB     := $(TSEAL_LIB_DIR)/libtSeal.a

SE_LIB_DIR    := $(LINUX_SDK_DIR)/selib/linux
SE_LIB        := $(SE_LIB_DIR)/libselib.a

EC_DH_LIB_DIR := $(LINUX_SDK_DIR)/ec_dh_lib
EC_DH_LIB     := $(EC_DH_LIB_DIR)/libsgx_dh.a

.PHONY: all
all: $(TSERVICE_SIM_LIB) | $(BUILD_DIR)
	$(CP) $^ $|

$(TSERVICE_SIM_LIB): $(EC_DH_LIB) $(TSEAL_LIB) $(SE_LIB)
	@$(MKDIR) $(BUILD_DIR)/.tservice_sim
	@$(RM) -f $(BUILD_DIR)/.tservice_sim/*
	cd $(BUILD_DIR)/.tservice_sim && $(AR) x $(EC_DH_LIB)
	cd $(BUILD_DIR)/.tservice_sim && $(AR) x $(TSEAL_LIB)
	cd $(BUILD_DIR)/.tservice_sim && $(AR) x $(SE_LIB)
	$(AR) rsD $@ $(BUILD_DIR)/.tservice_sim/*.o
	@$(RM) -rf  $(BUILD_DIR)/.tservice_sim

$(EC_DH_LIB):
	$(MAKE) -C $(EC_DH_LIB_DIR)

$(TSEAL_LIB):
	$(MAKE) -C $(TSEAL_LIB_DIR)

$(SE_LIB):
	$(MAKE) -C $(SE_LIB_DIR)

$(BUILD_DIR):
	@$(MKDIR) $@

.PHONY: clean
clean:
	$(MAKE) -C $(EC_DH_LIB_DIR) clean
	$(MAKE) -C $(TSEAL_LIB_DIR) clean
	$(MAKE) -C $(SE_LIB_DIR)    clean
	@$(RM) *.o $(TSERVICE_SIM_LIB) $(BUILD_DIR)/$(TSERVICE_SIM_LIB)
	@$(RM) $(COMMON_DIR)/src/*.o

.PHONY: rebuild
rebuild:
	$(MAKE) clean
	$(MAKE) all
