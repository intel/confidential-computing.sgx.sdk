#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../buildenv.mk

CFLAGS   += $(ENCLAVE_CFLAGS) -Werror=format-security -D_TLIBC_GNU_
ASFLAGS  := $(CFLAGS)
CFLAGS   += -std=c99
CXXFLAGS += $(ENCLAVE_CXXFLAGS) -fno-exceptions -fno-rtti -Werror=format-security

CPPFLAGS += -I.                          \
            -I$(COMMON_DIR)/inc          \
            -I$(COMMON_DIR)/inc/tlibc    \
            -I$(COMMON_DIR)/inc/internal \
            -I$(LINUX_SDK_DIR)/trts      \
            -I./string/asm               \
            -I./gdtoa

# TOMBSTONE: the USE_STRING_LIB=0 / USE_MATH_LIB=0 build paths (selected via
# USE_OPT_LIBS=2 or 3) defined _TLIBC_USE_INTEL_FAST_STRING_ and compiled the
# math/opt/*.c sources instead of math/*.c so the prebuilt optimized Intel
# libirc / libimf / libsvml objects (LIBIRC_PATH / LIBM_PATH / SVML_PATH) could
# be spliced in. That support was removed; the last release that shipped it is
# 2.29. Only the open-sourced string/math sources are built now.
LIBC_C_SRCS := $(wildcard gen/*.c gdtoa/*.c locale/*.c math/*.c stdlib/*.c string/*.c stdio/*.c time/*.c) 
LIBC_CPP_SRCS := $(wildcard gen/*.cpp) tstdc_version.cpp
LIBC_ASM_SRCS := $(wildcard gen/*.S math/*.S string/asm/*.S)

LIBC_OBJS := $(LIBC_C_SRCS:.c=.o)
LIBC_OBJS += $(LIBC_CPP_SRCS:.cpp=.o)
LIBC_OBJS += $(LIBC_ASM_SRCS:.S=.o)
LIBC_OBJS := $(sort $(LIBC_OBJS))

LIBC_NAME    := libtlibc.a

.PHONY: all
all: $(LIBC_NAME) | $(BUILD_DIR) 

$(LIBC_NAME): $(LIBC_OBJS)
	$(AR) rcs $@ $^

string/consttime_memequal.o: string/consttime_memequal.c
	$(CC)  $(filter-out -O2,$(CFLAGS)) -O1 $(CPPFLAGS) -c $< -o $@
	
%.o: %.c
	$(CC)  $(CFLAGS)   $(CPPFLAGS) -c $< -o $@

%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

%.o: %.S
	$(CC)  $(ASFLAGS)  $(CPPFLAGS) -c $< -o $@

$(BUILD_DIR):
	$(MKDIR) $@

.PHONY: clean
clean:
	@$(RM) $(LIBC_NAME) $(LIBC_OBJS)
