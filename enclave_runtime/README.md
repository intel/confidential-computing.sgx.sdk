# `enclave_runtime/`

Host-side SGX enclave runtime (launch) components of Intel&reg; SGX Platform Software (PSW): the Intel&reg; SGX untrusted runtime system (uRTS) and the enclave-common loader API used to create, load, initialize, and tear down enclaves.

For repository context see [../README.md#repository-layout](../README.md#repository-layout).

## What is in here

- [`urts/`](urts/): implementation of the Intel SGX untrusted runtime system (**uRTS**), which loads enclaves and dispatches ECALL/OCALL paths.
  - Builds `libsgx_urts.so` (public uRTS library).
    - uRTS is the untrusted/host runtime side; TRTS is the trusted/in-enclave runtime side [`libsgx_trts.a`](../sdk/trts/) bundled into the enclave image (simulation counterpart: [`libsgx_trts_sim.a`](../sdk/simulation/trtssim/linux/)). After uRTS loads and enters the enclave, TRTS runs inside that trusted address space; the public API boundary headers are [`sgx_urts.h`](../common/inc/sgx_urts.h) and [`sgx_trts.h`](../common/inc/sgx_trts.h), respectively.
  - [urts/parser/](urts/parser/) builds `libenclaveparser.a` used by build/signing flows that parse enclave metadata.
- [`enclave_common/`](enclave_common/): host-side enclave loader API used by uRTS and related host code to create enclaves, load pages, initialize them, query/set loader information, and delete them.
  - Builds `libsgx_enclave_common.so` (runtime library) and `libsgx_enclave_common.a` (static variant used at build/link time).

## Build-time usage

**High-level Overview:** `urts/` is the host-facing uRTS implementation (`libsgx_urts.so`), while `enclave_common/` provides the lower-level enclave loader API that uRTS builds on.

- uRTS and enclave_common both link the wrapper library [`libwrapper.a`](../common/se_wrapper/), which is built from [common](../common/src/) OS-abstraction helpers.

> [!NOTE]
> `liburts_internal.so` is built alongside `libsgx_urts.so` for internal/runtime-private use by the AESM side of the Intel&reg; SGX Platform Software (PSW); see the [Intel&reg; SGX PSW section](../README.md#build-the-intel-sgx-enclave-runtime-packages). In practice, its build differs from the public library mainly because it folds the objects from `libsgx_enclave_common.a` into the shared object, whereas `libsgx_urts.so` links `libsgx_enclave_common` dynamically.[^urts-internal]
> 
> Historically, before the [Intel&reg; SGX SDK/PSW 2.28 release](https://github.com/intel/confidential-computing.sgx/releases/tag/sgx_2.28), the analogous internal uRTS code in `psw/urts/linux/urts_internal.cpp` also exposed AESM-facing launch helpers such as `init_get_launch_token()`, `sgx_create_le()`, and `is_launch_token_required()` for the deprecated Launch Enclave / whitelist-management flow that 2.28 removed code support for.

[^urts-internal]: Implementation detail: the internal build also uses a separate linker version script, [`urts_internal.lds`](urts/linux/urts_internal.lds), with a narrower export surface than [`urts.lds`](urts/linux/urts.lds).

## Packaging mapping

- Runtime package content for enclave runtime is defined by:
  - [`libsgx-urts.txt`](../build_infrastructure/linux/installer/common/sgx-enclave-runtime/BOM_install/libsgx-urts.txt)
  - [`libsgx-enclave-common.txt`](../build_infrastructure/linux/installer/common/sgx-enclave-runtime/BOM_install/libsgx-enclave-common.txt)
- Dev/header package content is defined by:
  - [`libsgx-enclave-common-devel.txt`](../build_infrastructure/linux/installer/common/sgx-enclave-runtime/BOM_install/libsgx-enclave-common-devel.txt)
  - [`libsgx-headers.txt`](../build_infrastructure/linux/installer/common/sgx-enclave-runtime/BOM_install/libsgx-headers.txt)

## Make targets and build flavors

- Top-level entry points in [../Makefile](../Makefile):
  - `make enclave_runtime`: builds the uRTS runtime libraries via [`urts/linux`](urts/linux/) (which internally also builds `enclave_common` and `common/se_wrapper` as sub-make dependencies).
  - Package targets include `deb_libsgx_urts`, `rpm_libsgx_urts`, `deb_libsgx_enclave_common`, `rpm_libsgx_enclave_common`.
- Directory-local targets:
  - `make -C urts/linux` builds `libsgx_urts.so` and the internal companion `liburts_internal.so`.
  - `make -C enclave_common` builds `libsgx_enclave_common.so` and `libsgx_enclave_common.a`.
- Mitigation flavors:
  - Shared build flags in [../buildenv.mk](../buildenv.mk) support `MITIGATION-CVE-2020-0551=LOAD`, `MITIGATION-CVE-2020-0551=CF`, or unset (default).
  - `make sdk` (top-level) explicitly builds all three modes (LOAD, CF, default).
  - Runtime-only builds can be forced to a specific mode by passing the same variable to the runtime targets.
