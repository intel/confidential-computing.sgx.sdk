#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

TOP_DIR = ../..
include ../../buildenv.mk

CXXFLAGS += $(ENCLAVE_CXXFLAGS) -Werror -fno-exceptions -fno-rtti

#libsgx_pthread.a must be built with -fpic option, or pthread will crash in SIM mode
CXXFLAGS := $(subst -fpie,, $(CXXFLAGS))
CXXFLAGS += -fpic

CPPFLAGS := -I$(COMMON_DIR)/inc/internal \
            -I$(COMMON_DIR)/inc          \
            -I$(COMMON_DIR)/inc/tlibc    \
            -I$(COMMON_DIR)/../sdk/trts

OBJ := pthread.o \
       pthread_once.o \
       pthread_mutex.o \
       pthread_cond.o \
       pthread_tls.o \
       pthread_rwlock.o

EDGER8R_DIR = $(LINUX_SDK_DIR)/edger8r/linux
EDGER8R = $(EDGER8R_DIR)/_build/Edger8r.native
LIBPTHREAD := libsgx_pthread.a

.PHONY:all
all: $(LIBPTHREAD) | $(BUILD_DIR)
	$(CP) $(LIBPTHREAD) $|

pthread.o: $(COMMON_DIR)/inc/sgx_pthread_t.h

$(COMMON_DIR)/inc/sgx_pthread_t.h: $(COMMON_DIR)/inc/sgx_pthread.edl $(EDGER8R)
	$(EDGER8R) --header-only --trusted --search-path $(TOP_DIR)/common/inc sgx_pthread.edl

$(EDGER8R):
	$(MAKE) -C $(EDGER8R_DIR)

$(LIBPTHREAD): $(OBJ)
	$(AR) rcs $@ $^

$(OBJ): %.o: %.cpp
	$(CXX) -c $(CXXFLAGS) $(CPPFLAGS) $< -o $@

$(BUILD_DIR):
	@$(MKDIR) $@

.PHONY: clean
clean:
	@$(RM) *.o *.a $(BUILD_DIR)/$(LIBPTHREAD)
	@$(RM) sgx_pthread_t.*
	$(MAKE) -C $(EDGER8R_DIR) clean

.PHONY: rebuild
rebuild: 
	$(MAKE) clean
	$(MAKE) all
