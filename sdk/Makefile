#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../buildenv.mk

include Makefile.source

# IPP libraries must be ready for SDK build
CHECK_OPT :=
ifeq ("$(wildcard $(LINUX_EXTERNAL_DIR)/ippcp_internal/lib/linux/intel64)", "")
CHECK_OPT := opt_check_failed
endif

.PHONY: opt_check_failed
opt_check_failed:
	@echo "ERROR: Please go to top directory and run 'make preparation' to prepare the optimized libraries before compiling."
	@echo "	   If you want to build IPP Crypto libraries from source, please run 'make preparation' and then 'make ipp' to build them."
	@echo "	   Otherwise, run 'make preparation USE_PREBUILT_IPP=yes' to download the prebuilt IPP Crypto libraries."
	@echo "Exiting......"
	@exit 3

.PHONY: all
all: $(CHECK_OPT)
	$(MAKE) components
ifneq ($(filter LOAD CF,$(MITIGATION-CVE-2020-0551)),)
	@# Workaround for legacy SDK components that still build to build/linux instead of per-variant directories.
	@# 
	@# Legacy pattern: all components build to build/linux, then we move contents to build/linuxLOAD or build/linuxCF.
	@# Per-variant pattern (TVL): component builds directly to variant-specific directory from the start.
	@# 
	@# At this scope BUILD_DIR is always build/linux (from buildenv.mk), but per-variant components
	@# override it internally. We mkdir -p the target so we can mv into it regardless of whether
	@# it already exists (per-variant) or needs to be created (legacy).
	@# 
	@# We no longer rm -r the target first (would clobber per-variant output).
	@# That removal now happens in the clean target (Makefile.source) scoped to the specific MITIGATION value.
	@TARGET_DIR="$(BUILD_DIR)$(MITIGATION-CVE-2020-0551)"; \
	mkdir -p $$TARGET_DIR; \
	for entry in $(BUILD_DIR)/* $(BUILD_DIR)/.[!.]* $(BUILD_DIR)/..?*; do \
		[ -e "$$entry" ] || continue; \
		mv "$$entry" $$TARGET_DIR/; \
	done; \
	rmdir $(BUILD_DIR) 2>/dev/null || true
endif

.PHONY: rebuild
rebuild: 
	$(MAKE) clean 
	$(MAKE) all
