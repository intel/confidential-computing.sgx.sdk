#
# Copyright(c) 2011-2026 Intel Corporation
#
# SPDX-License-Identifier: BSD-3-Clause
#

include ../../../buildenv.mk

ifndef DEBUG
CXXFLAGS += -DDISABLE_TRACE
CFLAGS += -DDISABLE_TRACE
endif

CXXFLAGS += -fPIC -Werror -g
CXXFLAGS += $(ADDED_INC)

CFLAGS += -fPIC -Werror -g
CFLAGS += $(ADDED_INC)

VTUNE_DIR = $(LINUX_EXTERNAL_DIR)/vtune/linux
PREBUILT_OPENSSL_DIR := $(ROOT_DIR)/prebuilt/dcap/openssl
CRYPTO_LIB := -L$(PREBUILT_OPENSSL_DIR)/lib/linux64 -lcrypto

INC += -I$(SGX_HEADER_DIR)                \
       -I$(COMMON_DIR)/inc/internal       \
       -I$(COMMON_DIR)/inc/internal/linux \
       -I$(LINUX_PSW_DIR)/enclave_common  \
       -I$(LINUX_PSW_DIR)/urts/           \
       -I$(LINUX_PSW_DIR)/urts/linux      \
       -I$(LINUX_PSW_DIR)/urts/parser     \
       -I$(VTUNE_DIR)/include \
       -I$(VTUNE_DIR)/sdk/src/ittnotify   \
       -I$(PREBUILT_OPENSSL_DIR)/inc

LDFLAGS := -lwrapper
INTERNAL_LDFLAGS := -lwrapper
LDFLAGS += $(COMMON_LDFLAGS) -Wl,-Bdynamic -L$(BUILD_DIR) -lsgx_enclave_common -lpthread
INTERNAL_LDFLAGS += $(COMMON_LDFLAGS) -lpthread
LDFLAGS += -L$(VTUNE_DIR)/sdk/src/ittnotify -littnotify -ldl $(CRYPTO_LIB)
INTERNAL_LDFLAGS += -L$(VTUNE_DIR)/sdk/src/ittnotify -littnotify -ldl $(CRYPTO_LIB)
LDFLAGS += -Wl,--version-script=urts.lds -Wl,--gc-sections
INTERNAL_LDFLAGS += -Wl,--version-script=urts_internal.lds -Wl,--gc-sections

DIR1 := $(LINUX_PSW_DIR)/urts/linux
DIR2 := $(LINUX_PSW_DIR)/urts
DIR3 := $(LINUX_PSW_DIR)/urts/parser
DIR4 := $(LINUX_PSW_DIR)/urts/parser/linux
DIR5 := $(LINUX_PSW_DIR)/../common/src/linux
DIR6 := $(LINUX_PSW_DIR)/../common/src

LIB += -L$(COMMON_DIR)/se_wrapper \
       -L$(SGX_LIB_DIR)

OBJ1 := loader.o          \
        node.o            \
        se_detect.o       \
        enclave.o         \
        tcs.o             \
        enclave_mutex.o   \
        enclave_thread.o   \
        routine.o         \
        urts_xsave.o      \
        se_ocalls.o       \
        cpu_features.o    \
        cpu_features_ext.o    \
        urts_version.o    \
        enclave_creator_hw_com.o 

OBJ2 := urts.o               \
        enclave_creator_hw.o \
        misc.o               \
        sig_handler.o        \
        debugger_support.o   \
        get_thread_id.o      \
        prd_css_util.o       \
        urts_emm.o           \
        edmm_utility.o

OBJ3 := enter_enclave.o \
        xsave_gnu.o

OBJ4 := section.o \
        elfparser.o \
        shared_object_parser.o

OBJ5 := urts_internal.o

OBJ6 := crypto_evp_digest.o crypto_rsa_key.o crypto_rsa3072.o

CPP_OBJ := $(OBJ1) $(OBJ2) $(OBJ4) $(OBJ5) $(OBJ6)
URTS_OBJ     := $(OBJ3) $(OBJ1) $(OBJ2) $(OBJ4) $(OBJ6)
INTERNAL_OBJ := $(OBJ3) $(CPP_OBJ)


vpath %.cpp $(DIR1):$(DIR2):$(DIR3):$(DIR4):$(DIR6)
vpath %.S   $(DIR1):$(DIR5)

LIBWRAPPER            := libwrapper.a
LIBSGX_ENCLAVE_COMMON := libsgx_enclave_common.a
LIBURTS_INTERNAL      := liburts_internal.so
LIBURTS               := libsgx_urts.so
LIBURTS_FULL          := $(LIBURTS).$(call get_full_version,URTS_VERSION)
LIBURTS_MAJOR         := $(LIBURTS).$(call get_major_version,URTS_VERSION)

.PHONY: all
all: $(LIBURTS) $(LIBURTS_INTERNAL) | $(BUILD_DIR)
	@$(CP) $(LIBURTS)          $|/$(LIBURTS_FULL)
	@$(LN) $(LIBURTS_FULL)     $|/$(LIBURTS_MAJOR)
	@$(LN) $(LIBURTS_MAJOR)    $|/$(LIBURTS)
	@$(CP) $(LIBURTS_INTERNAL) $|

$(LIBURTS_INTERNAL): $(INTERNAL_OBJ) $(LIBWRAPPER) $(LIBSGX_ENCLAVE_COMMON) ittnotify
	@$(MKDIR) $(BUILD_DIR)/.sgx_enclave_common
	$(AR) x $(BUILD_DIR)/$(LIBSGX_ENCLAVE_COMMON) --output $(BUILD_DIR)/.sgx_enclave_common && \
	$(RM) $(BUILD_DIR)/.sgx_enclave_common/edmm_utility.o
	$(CXX) $(CXXFLAGS) -shared -Wl,-soname=$@ $(LIB) -o $@ $(INTERNAL_OBJ) $(BUILD_DIR)/.sgx_enclave_common/*.o $(INTERNAL_LDFLAGS)
	@$(RM) -r $(BUILD_DIR)/.sgx_enclave_common

$(LIBURTS): $(URTS_OBJ) $(LIBWRAPPER) $(LIBSGX_ENCLAVE_COMMON) ittnotify
	$(CXX) $(CXXFLAGS) -shared -Wl,-soname=$(LIBURTS_MAJOR) $(LIB) -o $@ $(URTS_OBJ) $(LDFLAGS)

$(CPP_OBJ): %.o: %.cpp
	$(CXX) -c $(CXXFLAGS) $(INC) $< -o $@

$(OBJ3): %.o: %.S
	$(CC) -c $(CFLAGS) $(INC) $< -o $@

$(LIBWRAPPER):
	$(MAKE) -C $(COMMON_DIR)/se_wrapper/

$(LIBSGX_ENCLAVE_COMMON):
	$(MAKE) -C $(LINUX_PSW_DIR)/enclave_common/

.PHONY: ittnotify
ittnotify:
	CFLAGS= CXXFLAGS= $(MAKE) -C $(VTUNE_DIR)/sdk/src/ittnotify

$(BUILD_DIR):
	@$(MKDIR) $@

.PHONY: clean
clean::
	@$(RM) *.o $(LIBURTS) $(LIBURTS_INTERNAL) \
		$(BUILD_DIR)/$(LIBURTS)           \
		$(BUILD_DIR)/$(LIBURTS_FULL)      \
		$(BUILD_DIR)/$(LIBURTS_MAJOR)     \
		$(BUILD_DIR)/$(LIBURTS_INTERNAL)
	$(MAKE) -C $(COMMON_DIR)/se_wrapper/    clean
	$(MAKE) -C $(LINUX_PSW_DIR)/enclave_common/ clean
	$(MAKE) -C $(VTUNE_DIR)/sdk/src/ittnotify   clean
