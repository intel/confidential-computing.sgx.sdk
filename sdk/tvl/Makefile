#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../buildenv.mk

TVL_CPP_SRCS := $(wildcard *.cpp)
TVL_OBJS := $(TVL_CPP_SRCS:.cpp=.o)

COMMON_INCLUDE	:= -I$(COMMON_DIR)/inc -I$(COMMON_DIR)/inc/tlibc -I$(LINUX_SDK_DIR)/tlibcxx/include
TVL_INC  += $(COMMON_INCLUDE)


TVL_LIB  := sgx_dcap_tvl
TVL_NAME := lib$(TVL_LIB).a

# Use per-variant build directories (pioneer pattern for future SDK-wide refactor)
# This enables incremental builds and avoids the clean-rebuild cycle of the legacy SDK pattern.
ifeq ($(MITIGATION-CVE-2020-0551), LOAD)
	BUILD_DIR := $(ROOT_DIR)/build/linuxLOAD
else ifeq ($(MITIGATION-CVE-2020-0551), CF)
	BUILD_DIR := $(ROOT_DIR)/build/linuxCF
else
	BUILD_DIR := $(ROOT_DIR)/build/linux
endif

# Per-module object directory for proper incremental builds
OBJDIR := $(BUILD_DIR)/obj/tvl
TVL_OBJS_FULL := $(addprefix $(OBJDIR)/, $(TVL_OBJS))

ifneq ($(DEBUG), 1)
    COMMON_FLAGS += -ffunction-sections -fdata-sections
endif

ENCLAVE_CXXFLAGS += $(SGX_COMMON_CXXFLAGS) $(COMMON_FLAGS) -fPIC

.PHONY: all

all: $(BUILD_DIR)/$(TVL_NAME)

$(BUILD_DIR):
	@$(MKDIR) $@

$(OBJDIR):
	@$(MKDIR) $@

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(ENCLAVE_CXXFLAGS) $(TVL_INC) -c $< -o $@
	@echo "CXX  <=  $<"

$(BUILD_DIR)/$(TVL_NAME): $(TVL_OBJS_FULL) | $(BUILD_DIR)
	$(AR) rsD $@ $^


.PHONY: clean

clean:
	@echo "Cleaning objects"
	@rm -rf $(OBJDIR)
	@rm -f $(BUILD_DIR)/$(TVL_NAME)
