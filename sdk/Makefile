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
ifneq ($(MITIGATION-CVE-2020-0551),)
	$(RM) -r $(BUILD_DIR)$(MITIGATION-CVE-2020-0551)
	mv $(BUILD_DIR) $(BUILD_DIR)$(MITIGATION-CVE-2020-0551)
endif

.PHONY: rebuild
rebuild: 
	$(MAKE) clean 
	$(MAKE) all
