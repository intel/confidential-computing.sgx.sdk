#
# Copyright(c) 2011-2026 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#

# Use the Makefile's own directory to avoid picking up an installConfig from
# a parent make's -I search path (inherited via MAKEFLAGS).
# Note: $(dir ...) preserves the trailing slash, so no separator is needed.
include $(dir $(lastword $(MAKEFILE_LIST)))installConfig

ACQUIRE_PSW_VERSION = $(shell awk  \
                     '$$2 ~ /$1/ { print substr($$3, 2, length($$3) - 2); }' \
                     $(SRCDIR)/common/inc/internal/se_version.h)

ECL_FULL_VER:= $(call ACQUIRE_PSW_VERSION,ENCLAVE_COMMON_VERSION)
ECL_MAJOR_VER:=$(word 1,$(subst ., ,$(ECL_FULL_VER)))
URTS_FULL_VER:= $(call ACQUIRE_PSW_VERSION,URTS_VERSION)
URTS_MAJOR_VER:=$(word 1,$(subst ., ,$(URTS_FULL_VER)))

# Use ENCLAVE_RUNTIME_MAKEFILE_DIR if provided (for recursive calls), otherwise derive from MAKEFILE_LIST
ENCLAVE_RUNTIME_MAKEFILE_DIR ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CUR_PATH:=$(ENCLAVE_RUNTIME_MAKEFILE_DIR)
BOM_PATH:=$(CUR_PATH)/BOM_install
GEN_SCRIPT:=$(realpath $(CUR_PATH)/../gen_source/copy_source.py)

PACKAGE_ROOT_PATH:=$(SRCDIR)/build/pkgroot

USR_LIB_PATH:=/usr/$(notdir $(shell gcc -print-multi-os-directory))/$(shell dpkg-architecture -qDEB_HOST_MULTIARCH 2> /dev/null)
USR_INC_PATH=/usr/$(INC_DIR)

TEST_COPYABLE = \( -d $1 -a -n "$$(shell ls -A $1 2> /dev/null)" \)

define PRE_INSTALL_TEMPLATE
pre_$(1): | $(PACKAGE_ROOT_PATH)
	python3 $(GEN_SCRIPT) --bom-file $(BOM_PATH)/$(1).txt \
			--src-path $(SRCDIR) --dst-path $$|/$(1)
endef

define INSTALL_DEV_LIB_TEMPLATE
$(1): pre_$(1) | $(PACKAGE_ROOT_PATH)
	install -d $$(shell readlink -m $(DESTDIR)/$$@)
	test $(call TEST_COPYABLE,$$|/$$@/$(LIB_DIR)) && (                 \
	install -d $$(shell readlink -m $(DESTDIR)/$$@/$(USR_LIB_PATH)) && \
	install $$|/$$@/$(LIB_DIR)/*.so $(DESTDIR)/$$@/$(USR_LIB_PATH)  && \
	rm -fr $$|/$$@/$(LIB_DIR) ) ||:
	test $(call TEST_COPYABLE,$$|/$$@/$(INC_DIR)) && (                 \
	install -d $$(shell readlink -m $(DESTDIR)/$$@/$(USR_INC_PATH)) && \
	install -d $$(shell readlink -m $(DESTDIR)/$$@/$(USR_LIB_PATH)) && \
	cp -fr $$|/$$@/$(INC_DIR)/* $(DESTDIR)/$$@/$(USR_INC_PATH)      && \
	rm -fr $$|/$$@/$(INC_DIR) ) ||:

post_$(1): $(1) | $(PACKAGE_ROOT_PATH)
	test $(call TEST_COPYABLE,$$|/$$<) && ( \
	cp -fr $$|/$$</* $(DESTDIR)/$$< ) ||:
endef

# Runtime libraries needed to load and run enclaves
RUNTIME_PKGS:= $(ENCLAVE_COMMON_PACKAGE) \
               $(URTS_PACKAGE)

# Developer headers and link-time symlinks
DEV_PKGS:= $(ENCLAVE_COMMON_DEV_PACKAGE) \
           $(SGX_HEADERS_PACKAGE)

ALL_PKGS:= $(RUNTIME_PKGS) $(DEV_PKGS)

$(foreach PKG,$(ALL_PKGS),$(eval $(call INSTALL_DEV_LIB_TEMPLATE,$(PKG))))
$(foreach PKG,$(ALL_PKGS),$(eval $(call PRE_INSTALL_TEMPLATE,$(PKG))))

PHONY+=$(ALL_PKGS)
PHONY+=$(foreach PKG,$(ALL_PKGS),pre_$(PKG))
PHONY+=$(foreach PKG,$(ALL_PKGS),post_$(PKG))

# Runtime package: real .so libraries plus their MAJOR-version symlinks
PHONY+=install-runtime
install-runtime: $(foreach PKG,$(RUNTIME_PKGS),post_$(PKG))
	cd $(shell readlink -m $(DESTDIR)/$(ENCLAVE_COMMON_PACKAGE)/$(USR_LIB_PATH))     && \
	mv libsgx_enclave_common.so libsgx_enclave_common.so.$(ECL_FULL_VER)             && \
	ln -fs libsgx_enclave_common.so.$(ECL_FULL_VER) libsgx_enclave_common.so.$(ECL_MAJOR_VER)
	cd $(shell readlink -m $(DESTDIR)/$(URTS_PACKAGE)/$(USR_LIB_PATH))      && \
	mv libsgx_urts.so libsgx_urts.so.$(URTS_FULL_VER)                       && \
	ln -fs libsgx_urts.so.$(URTS_FULL_VER) libsgx_urts.so.$(URTS_MAJOR_VER) && \
	ln -fs libsgx_urts.so.$(URTS_MAJOR_VER) libsgx_urts.so

# Developer package: headers plus the bare developer .so symlink
PHONY+=install-dev
install-dev: $(foreach PKG,$(DEV_PKGS),post_$(PKG))
	rm -fr $(shell readlink -m $(DESTDIR)/$(SGX_HEADERS_PACKAGE)/$(USR_LIB_PATH))
	cd $(shell readlink -m $(DESTDIR)/$(ENCLAVE_COMMON_DEV_PACKAGE)/$(USR_LIB_PATH)) && \
	ln -fs libsgx_enclave_common.so.$(ECL_MAJOR_VER) libsgx_enclave_common.so

install: install-runtime install-dev
	rm -fr $(PACKAGE_ROOT_PATH)
	mkdir -p $(DESTDIR)/license
	cp $(SRCDIR)/License.txt $(DESTDIR)/license

$(PACKAGE_ROOT_PATH):
	mkdir -p $@

.PHONY: $(PHONY)
.DEFAULT: install
