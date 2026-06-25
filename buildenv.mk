#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

# -----------------------------------------------------------------------------
# Function : parent-dir
# Arguments: 1: path
# Returns  : Parent dir or path of $1, with final separator removed.
# -----------------------------------------------------------------------------
parent-dir = $(patsubst %/,%,$(dir $(1:%/=%)))

# -----------------------------------------------------------------------------
# Macro    : my-dir
# Returns  : the directory of the current Makefile
# Usage    : $(my-dir)
# -----------------------------------------------------------------------------
my-dir = $(realpath $(call parent-dir,$(lastword $(MAKEFILE_LIST))))


ROOT_DIR              := $(call my-dir)
ifneq ($(words $(subst :, ,$(ROOT_DIR))), 1)
  $(error main directory cannot contain spaces nor colons)
endif

# Packaging output root (contains bin/, deb/, rpm/ artifact dirs).
# Override when vendored, e.g. PKG_OUT_ROOT_DIR=$(ROOT_DIR)/../linux/installer
PKG_OUT_ROOT_DIR       ?= $(ROOT_DIR)/build_infrastructure/linux/installer
export PKG_OUT_ROOT_DIR
# When FLATTEN_PKG_OUT_DIR=1, packages will be placed directly in PKG_OUT_ROOT_DIR/<type> (e.g. deb/, rpm/, bin/)
# otherwise they will be placed in subdirs by component (e.g. deb/libsgx-enclave-common/)
FLATTEN_PKG_OUT_DIR    ?= 0
export FLATTEN_PKG_OUT_DIR


#--------------------------------------------------------------------------------------
# Function: get_distr_info
# Arguments: 1: the grep keyword to be searched from /etc/os-release
# Returns: Return the value for the Linux distribution info corresponding to the keyword
#---------------------------------------------------------------------------------------
get_distr_info = $(patsubst "%",%,$(shell grep $(1) /etc/os-release 2> /dev/null | awk -F'=' '{print $$2}'))

DISTR_ID := $(call get_distr_info, '^ID=')
DISTR_VER := $(call get_distr_info, '^VERSION_ID=')

# Release packaging format selection (used by top-level "release" target)
# Override with RELEASE_PKG_FORMAT=deb|rpm; otherwise auto-detect.
# NOTE: Auto-detection and validation only trigger when building packaging targets (deb_*, rpm_*, release).
# This avoids parse-time errors on clean/distclean and other non-packaging targets.
RELEASE_PKG_FORMAT ?= auto

DEB_LIKE_IDS := ubuntu debian
RPM_LIKE_IDS := rhel centos fedora rocky almalinux amzn ol sles opensuse opensuse-leap suse
OS_RELEASE_ID_LIKE := $(call get_distr_info, '^ID_LIKE=')

# Check if any packaging target is being built
_NEEDS_PKG_FORMAT := $(if $(filter release deb% rpm%,$(MAKECMDGOALS)),yes,)

# Only validate/auto-detect RELEASE_PKG_FORMAT when packaging targets are needed
ifeq ($(_NEEDS_PKG_FORMAT),yes)
ifeq ($(RELEASE_PKG_FORMAT),auto)
# Auto-detect if not explicitly set
PKG_OS_HINT := $(if $(filter $(DISTR_ID) $(OS_RELEASE_ID_LIKE),$(DEB_LIKE_IDS)),deb,$(if $(filter $(DISTR_ID) $(OS_RELEASE_ID_LIKE),$(RPM_LIKE_IDS)),rpm,))
PKG_DB_HINT := $(shell if [ -e /var/lib/dpkg/status ] && [ ! -d /var/lib/rpm ] && [ ! -d /usr/lib/sysimage/rpm ]; then echo deb; elif { [ -d /var/lib/rpm ] || [ -d /usr/lib/sysimage/rpm ]; } && [ ! -e /var/lib/dpkg/status ]; then echo rpm; fi)
PKG_CMD_HINT := $(shell if command -v dpkg >/dev/null 2>&1 && ! command -v rpm >/dev/null 2>&1; then echo deb; elif command -v rpm >/dev/null 2>&1 && ! command -v dpkg >/dev/null 2>&1; then echo rpm; fi)
RELEASE_PKG_FORMAT := $(firstword $(PKG_OS_HINT) $(PKG_DB_HINT) $(PKG_CMD_HINT))
ifeq ($(RELEASE_PKG_FORMAT),)
$(error Unable to auto-detect packaging format (DISTR_ID='$(DISTR_ID)', ID_LIKE='$(OS_RELEASE_ID_LIKE)'). Set RELEASE_PKG_FORMAT=deb|rpm)
endif
endif

# Validate format is one of: auto, deb, rpm
ifneq (,$(filter $(RELEASE_PKG_FORMAT),auto deb rpm))
else
$(error RELEASE_PKG_FORMAT must be one of: auto, deb, rpm)
endif
endif

#--------------------------------------------------------------------------------------
# Function: get_full_version
# Arguments: 1: the version name of library
# Returns: Return the full version.
#---------------------------------------------------------------------------------------
get_full_version = $(shell awk '$$2 ~ /$1/ { print substr($$3, 2, length($$3) - 2); }' $(SE_VERSION_FILE))

#--------------------------------------------------------------------------------------
# Function: get_major_version
# Arguments: 1: the version name of library
# Returns: Return the major version.
#---------------------------------------------------------------------------------------
get_major_version = $(word 1,$(subst ., ,$(call get_full_version,$1)))

COMMON_DIR                := $(ROOT_DIR)/common
SE_VERSION_FILE           := $(COMMON_DIR)/inc/internal/se_version.h
LINUX_EXTERNAL_DIR        := $(ROOT_DIR)/external
LINUX_ENCLAVE_RUNTIME_DIR := $(ROOT_DIR)/enclave_runtime
LINUX_SDK_DIR             := $(ROOT_DIR)/sdk
LIBUNWIND_DIR             := $(ROOT_DIR)/sdk/cpprt/linux/libunwind
SDK_VERSION_DEFAULT       := $(call get_full_version,STRFILEVER_DEFAULT)

# Set repo-wide SGX_SDK_VERSION (all components within this repo)with default fallback
SGX_SDK_VERSION           ?= $(SDK_VERSION_DEFAULT)
# Version override specifically for components which are part of the SDK package (incl. libsgx_headers)
SDK_VERSION               ?= $(SGX_SDK_VERSION)
# Version override specifically for components which are part of the Enclave Runtime package (incl. libsgx_enclave_common, libsgx_urts)
ENCLAVE_RUNTIME_VERSION   ?= $(SGX_SDK_VERSION)

# Export globally for sub-makes/shell scripts
export SGX_SDK_VERSION
export SDK_VERSION
export ENCLAVE_RUNTIME_VERSION

# Limitation: some targets currently embed version info from SE_VERSION_FILE at build time,
# while installer/deb/rpm packaging flows consume SDK_VERSION or ENCLAVE_RUNTIME_VERSION
# (with SGX_SDK_VERSION retained as a backward-compatible fallback).
# Until we add a dedicated target that generates the version file from a template, keep
# mismatch as warning-only and continue the build.
ifneq ($(SGX_SDK_VERSION),$(SDK_VERSION_DEFAULT))
$(warning Non-fatal version mismatch: requested SGX_SDK_VERSION=$(SGX_SDK_VERSION), but $(SE_VERSION_FILE) defines $(SDK_VERSION_DEFAULT). This legacy fallback may still affect package versions when SDK_VERSION/ENCLAVE_RUNTIME_VERSION are not set. Continuing.)
endif
ifneq ($(SDK_VERSION),$(SDK_VERSION_DEFAULT))
$(warning Non-fatal version mismatch: requested SDK_VERSION=$(SDK_VERSION), but $(SE_VERSION_FILE) defines $(SDK_VERSION_DEFAULT). SDK package metadata/artifacts use SDK_VERSION, while some compiled outputs may still embed the header version. Continuing.)
endif
ifneq ($(ENCLAVE_RUNTIME_VERSION),$(SDK_VERSION_DEFAULT))
$(warning Non-fatal version mismatch: requested ENCLAVE_RUNTIME_VERSION=$(ENCLAVE_RUNTIME_VERSION), but $(SE_VERSION_FILE) defines $(SDK_VERSION_DEFAULT). Enclave Runtime package metadata/artifacts use ENCLAVE_RUNTIME_VERSION, while some compiled outputs may still embed the header version. Continuing.)
endif

CP    := cp -f
LN    := ln -sf
MKDIR := mkdir -p
STRIP := strip
OBJCOPY := objcopy
NIPX := .nipx
NIPD := .nipd
NIPRODT := .niprod
CC ?= gcc

CC_VERSION := $(shell $(CC) -dumpversion)
CC_VERSION_MAJOR := $(shell echo $(CC_VERSION) | cut -f1 -d.)
CC_VERSION_MINOR := $(shell echo $(CC_VERSION) | cut -f2 -d.)
CC_NO_LESS_THAN_8 := $(shell [ $(CC_VERSION_MAJOR) -ge 8 ] && echo 1 || echo 0)
CC_NO_LESS_THAN_12 := $(shell [ $(CC_VERSION_MAJOR) -ge 12 ] && echo 1 || echo 0)

ifeq ($(CC_NO_LESS_THAN_12), 1)
    FORTIFY_SOURCE_VAL := 3
else
    FORTIFY_SOURCE_VAL := 2
endif

# clean the content of 'INCLUDE' - this variable will be set by vcvars32.bat
# thus it will cause build error when this variable is used by our Makefile,
# when compiling the code under Cygwin tainted by MSVC environment settings.
INCLUDE :=

# this will return the path to the file that included the buildenv.mk file
CUR_DIR := $(realpath $(call parent-dir,$(lastword $(wordlist 2,$(words $(MAKEFILE_LIST)),x $(MAKEFILE_LIST)))))

# Normalize DEBUG so that 0 or empty behaves exactly like "not defined",
# including for "ifdef DEBUG" checks in sub-makes (drop it from MAKEOVERRIDES/env).
# After this, a plain "ifdef DEBUG" is correct: defined (non-zero) => debug.
ifneq ($(origin DEBUG),undefined)
ifeq ($(filter-out 0,$(strip $(DEBUG))),)
override undefine DEBUG
override MAKEOVERRIDES := $(filter-out DEBUG=%,$(MAKEOVERRIDES))
unexport DEBUG
endif
endif
ifdef DEBUG
    COMMON_FLAGS += -O0 -ggdb -DDEBUG -UNDEBUG
    COMMON_FLAGS += -DSE_DEBUG_LEVEL=SE_TRACE_DEBUG
else
    COMMON_FLAGS += -O2 -D_FORTIFY_SOURCE=$(FORTIFY_SOURCE_VAL) -UDEBUG -DNDEBUG
endif

ifdef SE_SIM
    COMMON_FLAGS += -DSE_SIM
endif

ifdef SERVTD_ATTEST
    COMMON_FLAGS += -DSERVTD_ATTEST
endif

ifeq ($(CC_NO_LESS_THAN_8), 1)
    COMMON_FLAGS += -fstack-clash-protection
endif

COMMON_FLAGS += -ffunction-sections -fdata-sections -fstack-protector-strong -D_GLIBCXX_ASSERTIONS

# turn on compiler warnings as much as possible
COMMON_FLAGS += -Wall -Wextra -Winit-self -Wpointer-arith -Wreturn-type \
		-Waddress -Wsequence-point -Wformat-security \
		-Wmissing-include-dirs -Wfloat-equal -Wundef -Wshadow \
		-Wcast-align -Wconversion -Wredundant-decls -Wimplicit-fallthrough

# additional warnings flags for C
CFLAGS += -Wjump-misses-init -Wstrict-prototypes -Wunsuffixed-float-constants

# additional warnings flags for C++
CXXFLAGS += -Wnon-virtual-dtor

CXXFLAGS += -std=c++17

.DEFAULT_GOAL := all
# this turns off the RCS / SCCS implicit rules of GNU Make
% : RCS/%,v
% : RCS/%
% : %,v
% : s.%
% : SCCS/s.%

# If a rule fails, delete $@.
.DELETE_ON_ERROR:

HOST_FILE_PROGRAM := file

UNAME := $(shell uname -m)
ifneq (,$(findstring 86,$(UNAME)))
    HOST_ARCH := x86
    ifneq (,$(shell $(HOST_FILE_PROGRAM) -L $(SHELL) | grep 'x86[_-]64'))
        HOST_ARCH := x86_64
    endif
else
    $(info Unknown host CPU architecture $(UNAME))
    $(error Aborting)
endif

BUILD_DIR := $(ROOT_DIR)/build/linux

ifeq "$(findstring __INTEL_COMPILER, $(shell $(CC) -E -dM -xc /dev/null))" "__INTEL_COMPILER"
  ifeq ($(shell test -f /usr/bin/dpkg; echo $$?), 0)
    ADDED_INC := -I /usr/include/$(shell dpkg-architecture -qDEB_BUILD_MULTIARCH)
  endif
endif

ARCH := $(HOST_ARCH)
ifeq "$(findstring -m32, $(CXXFLAGS))" "-m32"
  ARCH := x86
endif

ifeq ($(ARCH), x86)
COMMON_FLAGS += -DITT_ARCH_IA32
else
COMMON_FLAGS += -DITT_ARCH_IA64
endif


CET_FLAGS :=
ifeq ($(CC_NO_LESS_THAN_8), 1)
    CET_FLAGS += -fcf-protection
endif

CFLAGS   += $(COMMON_FLAGS)
CXXFLAGS += $(COMMON_FLAGS)

# Enable the security flags
COMMON_LDFLAGS := -Wl,-z,relro,-z,now,-z,noexecstack

# mitigation options
MITIGATION_INDIRECT ?= 0
MITIGATION_RET ?= 0
MITIGATION_C ?= 0
MITIGATION_ASM ?= 0
MITIGATION_AFTERLOAD ?= 0
MITIGATION_LIB_PATH :=

ifeq ($(MITIGATION-CVE-2020-0551), LOAD)
    MITIGATION_C := 1
    MITIGATION_ASM := 1
    MITIGATION_INDIRECT := 1
    MITIGATION_RET := 1
    MITIGATION_AFTERLOAD := 1
    MITIGATION_LIB_PATH := cve_2020_0551_load
else ifeq ($(MITIGATION-CVE-2020-0551), CF)
    MITIGATION_C := 1
    MITIGATION_ASM := 1
    MITIGATION_INDIRECT := 1
    MITIGATION_RET := 1
    MITIGATION_AFTERLOAD := 0
    MITIGATION_LIB_PATH := cve_2020_0551_cf
endif

ifneq ($(origin NIX_STORE), environment)
BINUTILS_DIR ?= /usr/local/bin
EXT_BINUTILS_DIR = $(ROOT_DIR)/external/toolset/$(DISTR_ID)$(DISTR_VER)
ENC_LDFLAGS = -B$(BINUTILS_DIR)
# enable -B option for all the build
MITIGATION_CFLAGS += -B$(BINUTILS_DIR)
endif


ifeq ($(MITIGATION_C), 1)
ifeq ($(MITIGATION_INDIRECT), 1)
    MITIGATION_CFLAGS += -mindirect-branch-register
endif
ifeq ($(MITIGATION_RET), 1)
ifeq ($(CC_NO_LESS_THAN_8), 1)
    MITIGATION_CFLAGS += -fcf-protection=none
endif
    MITIGATION_CFLAGS += -mfunction-return=thunk-extern
endif
endif

ifeq ($(MITIGATION_ASM), 1)
    MITIGATION_ASFLAGS += -fno-plt
ifeq ($(MITIGATION_AFTERLOAD), 1)
    MITIGATION_ASFLAGS += -Wa,-mlfence-after-load=yes -Wa,-mlfence-before-indirect-branch=memory
else
    MITIGATION_ASFLAGS += -Wa,-mlfence-before-indirect-branch=all
endif
ifeq ($(MITIGATION_RET), 1)
    MITIGATION_ASFLAGS += -Wa,-mlfence-before-ret=shl
endif
endif

MITIGATION_CFLAGS += $(MITIGATION_ASFLAGS)

# fcf-protection is not compatible with MITIGATION
ifneq ($(MITIGATION_RET), 1)
    CFLAGS   += $(CET_FLAGS)
    CXXFLAGS += $(CET_FLAGS)
endif

# Compiler and linker options for an Enclave
#
# We are using '--export-dynamic' so that `g_global_data_sim' etc.
# will be exported to dynamic symbol table.
#
# When `pie' is enabled, the linker (both BFD and Gold) under Ubuntu 14.04
# will hide all symbols from dynamic symbol table even if they are marked
# as `global' in the LD version script.
ENCLAVE_CFLAGS   = -ffreestanding -nostdinc -fvisibility=hidden -fpie -fno-strict-overflow -fno-delete-null-pointer-checks
ENCLAVE_CXXFLAGS = $(ENCLAVE_CFLAGS) -nostdinc++
ENCLAVE_LDFLAGS  = $(ENC_LDFLAGS) $(COMMON_LDFLAGS) -Wl,-Bstatic -Wl,-Bsymbolic -Wl,--no-undefined \
                   -Wl,-pie,-eenclave_entry -Wl,--export-dynamic  \
                   -Wl,--defsym,__ImageBase=0

ENCLAVE_CFLAGS += $(MITIGATION_CFLAGS)
ENCLAVE_ASFLAGS = $(MITIGATION_ASFLAGS)

# We have below choices as to the crypto lib:
#   crypto - SGXSSL (0), IPP crypto (1) [default]
#
# A macro 'USE_OPT_LIBS' selects the crypto library combination.
# By default, build the SDK using optimized IPP crypto.
#
# LEGACY: USE_OPT_LIBS=2 and USE_OPT_LIBS=3 used to select the prebuilt,
# closed-source "optimized" Intel string/math libraries (libirc / SVML /
# Libm_ct); the last release that shipped them is 2.29.
#
# IPP + open sourced string + open sourced math
USE_OPT_LIBS ?= 1
USE_CRYPTO_LIB ?= 1

ifeq ($(USE_OPT_LIBS), 0)
# SGXSSL + open sourced string + open sourced math
    USE_CRYPTO_LIB := 0
$(warning DEPRECATION: USE_OPT_LIBS=0 (SGXSSL crypto) is deprecated and planned to be removed in a future release; prefer USE_OPT_LIBS=1 (IPP - default).)
else ifneq ($(filter 2 3,$(USE_OPT_LIBS)),)
$(error ERROR: USE_OPT_LIBS=$(USE_OPT_LIBS) (optimized string/math) was removed; the last release supporting it is 2.29. Use USE_OPT_LIBS=0 (SGXSSL) or USE_OPT_LIBS=1 (IPP - default).)
else ifneq ($(USE_OPT_LIBS), 1)
$(error ERROR: invalid USE_OPT_LIBS=$(USE_OPT_LIBS); valid values are 0 (SGXSSL) or 1 (IPP - default).)
endif


IPP_SUBDIR = no_mitigation
ifeq ($(MITIGATION-CVE-2020-0551), LOAD)
    IPP_SUBDIR = cve_2020_0551_load
else ifeq ($(MITIGATION-CVE-2020-0551), CF)
    IPP_SUBDIR = cve_2020_0551_cf
endif


SGX_IPP_DIR     := $(ROOT_DIR)/external/ippcp_internal
SGX_IPP_INC     := $(SGX_IPP_DIR)/inc
IPP_LIBS_DIR    := $(SGX_IPP_DIR)/lib/linux/intel64/$(IPP_SUBDIR)
LD_IPP          := -lippcp

######## SGX SDK Settings (source layout) ########
SGX_HEADER_DIR := $(ROOT_DIR)/sdk/include
