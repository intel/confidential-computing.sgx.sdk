#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../../buildenv.mk

SIM_DIR := $(CUR_DIR)/..

ifndef DEBUG
CXXFLAGS += -DDISABLE_TRACE
CFLAGS += -DDISABLE_TRACE
endif

CPPFLAGS += $(ADDED_INC)
CPPFLAGS += -I$(COMMON_DIR)/inc/         \
            -I$(COMMON_DIR)/inc/internal \
            -I$(SIM_DIR)/assembly/       \
            -I$(SIM_DIR)/assembly/linux  \
            -I$(SIM_DIR)/tinst/          \
            -I$(LINUX_ENCLAVE_RUNTIME_DIR)/urts      \
            -I$(LINUX_ENCLAVE_RUNTIME_DIR)/urts/linux

CXXFLAGS += -Werror -fPIC $(CET_FLAGS)

OBJ1 := linux/set_tls.o \
        linux/restore_tls.o \
        linux/get_tcs.o

LIBSESIMU_U := libsesimu_u.a

.PHONY:all
all: $(LIBSESIMU_U)

enclave_mngr.o: enclave_mngr.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

# Explicitly disable optimization for 'u_instructions.cpp',
# since the '_SE3' function has assumptions on stack layout.
#
u_instructions.o: u_instructions.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -O0 -Wno-error=cpp -c $< -o $@

$(LIBSESIMU_U): u_instructions.o enclave_mngr.o $(OBJ1)
	$(AR) rcs $@ $^

$(OBJ1):
	$(MAKE) -C linux

.PHONY: clean
clean:
	$(MAKE) -C linux clean
	@$(RM) *.o *.a *.so
