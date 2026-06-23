#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#


include ../../../buildenv.mk

SIM_DIR  := $(CUR_DIR)/..

CPPFLAGS += $(ADDED_INC) # for unbuntu 11 and later version
CPPFLAGS += -I$(COMMON_DIR)/inc/           \
            -I$(COMMON_DIR)/inc/internal   \
            -I$(COMMON_DIR)/inc/tlibc      \
            -I$(SIM_DIR)/assembly/         \
            -I$(SIM_DIR)/assembly/linux    \
            -I$(SIM_DIR)/uinst/            \
            -I$(LINUX_ENCLAVE_RUNTIME_DIR)/urts/linux  \
            -I$(LINUX_SDK_DIR)/selib

CXXFLAGS += $(ENCLAVE_CXXFLAGS) -Werror -fno-exceptions -fno-rtti

LIBSESIMU_T := libsesimu_t.a

OBJS := deriv.o t_instructions.o

.PHONY:all
all: $(LIBSESIMU_T)

$(LIBSESIMU_T): $(OBJS)
	$(AR) rcs $@ $^

.PHONY: clean
clean:
	@$(RM) $(OBJS) $(LIBSESIMU_T)
