#
# Copyright (C) 2025 Intel Corporation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#   * Neither the name of Intel Corporation nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#

include ../../buildenv.mk

SRCDIR   := libcxxrt_code/src
CPPRT    := libcxxrt.a

CFLAGS   += $(ENCLAVE_CFLAGS)
CXXFLAGS += $(ENCLAVE_CXXFLAGS)

CPPFLAGS += -I$(COMMON_DIR)/inc           \
            -I$(COMMON_DIR)/inc/tlibc     \
            -I$(COMMON_DIR)/inc/stdc++    \
            -I$(COMMON_DIR)/inc/internal  \

CPPFLAGS += -I$(LINUX_SDK_DIR)/trts       \
            -I$(LINUX_SDK_DIR)/trts/linux \

# LIBCXXRT_NO_DEFAULT_TERMINATE_DIAGNOSTICS: diagnostics are written using printf but printf is not available in sgx_tcxx
# LIBCXXRT_NO_EMERGENCY_MALLOC: if enabled sgx_tcxx will depend on sgx_pthread
# INTEL_SGX_MOD: apply Intel customizations for libcxxrt
CFLAGS   += -DLIBCXXRT_NO_DEFAULT_TERMINATE_DIAGNOSTICS -DLIBCXXRT_NO_EMERGENCY_MALLOC -DINTEL_SGX_MOD
CXXFLAGS += -DLIBCXXRT_NO_DEFAULT_TERMINATE_DIAGNOSTICS -DLIBCXXRT_NO_EMERGENCY_MALLOC -DINTEL_SGX_MOD

# Excluding memory.cc, noexception.cc and libelftc_dem_gnu3.c from compilation because they are not needed for tcxx build. Excluding
# unnecessary files from compilation narrows the attack surface
# Excluding noexception.cc file is necessary because both files (exception.cc and noexception.cc) contain an implementation of
# uncaught_exception() and uncaught_exceptions() functions. libcxxrt library can be built with or without exception support. For
# SGX needs, it is built with exception support
CC_SRCS  := $(filter-out $(SRCDIR)/memory.cc $(SRCDIR)/noexception.cc, $(wildcard $(SRCDIR)/*.cc))
C_SRCS   := $(filter-out $(SRCDIR)/libelftc_dem_gnu3.c, $(wildcard $(SRCDIR)/*.c))

CC_OBJS  := $(CC_SRCS:.cc=.o)
C_OBJS   := $(C_SRCS:.c=.o)

OBJS := $(sort $(C_OBJS) $(CC_OBJS))

$(C_OBJS): %.o: %.c
	$(CC) -c  $(CFLAGS)   $(CPPFLAGS) $< -o $@

$(CC_OBJS): %.o: %.cc
	$(CXX) -c $(CXXFLAGS) $(CPPFLAGS) $< -o $@

.PHONY: all
all: $(CPPRT)

$(CPPRT): $(OBJS)
	$(AR) rs $@ $(OBJS)

.PHONY: clean
clean:
	@$(RM) $(OBJS) $(CPPRT)

