#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../../buildenv.mk

SIM_DIR := $(CUR_DIR)/..

CPPFLAGS += $(ADDED_INC)
CPPFLAGS += -I$(COMMON_DIR)/inc/               \
            -I$(COMMON_DIR)/inc/internal       \
            -I$(SIM_DIR)/assembly/             \
            -I$(SIM_DIR)/uinst                 \
            -I$(SIM_DIR)/urtssim               \
            -I$(SIM_DIR)/tinst                 \
            -I$(LINUX_ENCLAVE_RUNTIME_DIR)/urts            \
            -I$(LINUX_ENCLAVE_RUNTIME_DIR)/urts/linux

CXXFLAGS += -fPIC -Werror $(CET_FLAGS)

.PHONY: all
all: driver_api.o

.PHONY: clean
clean:
	@$(RM) *.o
