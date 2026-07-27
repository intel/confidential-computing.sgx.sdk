#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

SGX_TRUSTED_INCLUDE_PATH ?= $(SGX_SDK)/include
SGX_TRUSTED_LIBRARY_PATH ?= $(SGX_SDK)/lib64

CC ?= gcc
CC_VERSION := $(shell $(CC) -dumpversion)
CC_NO_LESS_THAN_8 := $(shell expr $(CC_VERSION) \>\= "8")
BINUTILS_DIR ?= /usr/local/bin

# Mitigation options

MITIGATION_CFLAGS += -B$(BINUTILS_DIR)
MITIGATION_LDFLAGS += -B$(BINUTILS_DIR)

ifeq ($(MITIGATION-CVE-2020-0551), LOAD)
ifeq ($(CC_NO_LESS_THAN_8), 1)
    MITIGATION_CFLAGS += -fcf-protection=none
endif
    MITIGATION_CFLAGS += -mindirect-branch-register -mfunction-return=thunk-extern
    MITIGATION_ASFLAGS := -Wa,-mlfence-after-load=yes -Wa,-mlfence-before-indirect-branch=memory -Wa,-mlfence-before-ret=shl
    MITIGATION_ASFLAGS += -fno-plt
    SGX_TRUSTED_LIBRARY_PATH := $(SGX_TRUSTED_LIBRARY_PATH)/cve_2020_0551_load
else ifeq ($(MITIGATION-CVE-2020-0551), CF)
ifeq ($(CC_NO_LESS_THAN_8), 1)
    MITIGATION_CFLAGS += -fcf-protection=none
endif
    MITIGATION_CFLAGS += -mindirect-branch-register -mfunction-return=thunk-extern
    MITIGATION_ASFLAGS := -Wa,-mlfence-before-indirect-branch=all -Wa,-mlfence-before-ret=shl
    MITIGATION_ASFLAGS += -fno-plt
    SGX_TRUSTED_LIBRARY_PATH := $(SGX_TRUSTED_LIBRARY_PATH)/cve_2020_0551_cf
endif


MITIGATION_CFLAGS += $(MITIGATION_ASFLAGS)

# INSTALLED_SGX_SDK_VERSION: version of the installed Intel SGX SDK, e.g. 2.30.100.1.
# (Empty only in an un-installed source tree, where version checks are skipped.)
INSTALLED_SGX_SDK_VERSION := @SDK_PKG_VERSION@
ifneq ($(findstring @,$(INSTALLED_SGX_SDK_VERSION)),)
    INSTALLED_SGX_SDK_VERSION :=
endif

# Compares dotted versions numerically; "1" when $(1) >= $(2), else empty.
# Strips any pre-release/build suffix (e.g., "2.30-alpha" -> "2.30") before comparing.
_sgx_version_ge = $(shell awk -v v1="$(1)" -v v2="$(2)" 'BEGIN{sub(/[-+].*/,"",v1);sub(/[-+].*/,"",v2);n=split(v1,a,".");m=split(v2,b,".");k=(n>m)?n:m;for(i=1;i<=k;i++){x=(i<=n)?a[i]+0:0;y=(i<=m)?b[i]+0:0;if(x>y){print 1;exit}if(x<y)exit}print 1}')

# SGX_SDK_VERSION_AT_LEAST: use in a condition to branch on the SDK version.
#   ifneq ($(call SGX_SDK_VERSION_AT_LEAST,2.30),)   # true when SDK is >= 2.30
SGX_SDK_VERSION_AT_LEAST = $(if $(INSTALLED_SGX_SDK_VERSION),$(call _sgx_version_ge,$(INSTALLED_SGX_SDK_VERSION),$(1)),)

# REQUIRE_SGX_SDK_VERSION: stop the build unless the SDK is at least the given version.
#   $(call REQUIRE_SGX_SDK_VERSION,2.27)
REQUIRE_SGX_SDK_VERSION = $(strip \
    $(if $(INSTALLED_SGX_SDK_VERSION),\
        $(if $(call SGX_SDK_VERSION_AT_LEAST,$(1)),,\
            $(error Intel SGX SDK >= $(1) is required, but $(SGX_SDK) provides version $(INSTALLED_SGX_SDK_VERSION))),\
        $(warning Intel SGX SDK version is unknown; cannot verify the >= $(1) requirement)))
