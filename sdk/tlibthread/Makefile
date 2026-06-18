#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../buildenv.mk

CXXFLAGS += $(ENCLAVE_CXXFLAGS) -Werror -fno-exceptions -fno-rtti

CPPFLAGS := -I$(COMMON_DIR)/inc/internal \
            -I$(COMMON_DIR)/inc          \
            -I$(COMMON_DIR)/inc/tlibc    \
            -I$(COMMON_DIR)/../sdk/trts

OBJ := sethread_mutex.o \
       sethread_spinlock.o \
       sethread_rwlock.o \
       sethread_cond.o \
       sethread_utils.o

LIBTLIBTHREAD := libtlibthread.a

.PHONY:all
all: $(LIBTLIBTHREAD)

$(LIBTLIBTHREAD): $(OBJ)
	$(AR) rcs $@ $^

$(OBJ): %.o: %.cpp
	$(CXX) -c $(CXXFLAGS) $(CPPFLAGS) $< -o $@

.PHONY: clean
clean:
	@$(RM) *.o *.a

.PHONY: rebuild
rebuild: 
	$(MAKE) clean
	$(MAKE) all
