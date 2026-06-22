# `common/`

Shared headers and utility code used by both the SDK and enclave runtime builds.

For repository context see [`../README.md#repository-layout`](../README.md#repository-layout).

## What is in here

- [`inc/`](inc/): SGX headers consumed by SDK and runtime components.
  - Includes **public** SGX API headers (for example `sgx_urts.h`, `sgx_report.h`, `sgx_trts.h`) - stable API, kept backward-compatible by default (unless explicitly specified).
  - Also includes EDL files and SDK support headers (`tlibc/`, `stdc++/`).
- [`inc/internal/`](inc/internal/): **internal** build headers for in-tree components (*not* intended as external API).
- [`src/`](src/): shared utility/source files (memory, threading, tracing, crypto helpers, etc.) reused by both the SDK and the runtime libraries builds.
- [`se_wrapper/`](se_wrapper/): builds `libwrapper.a`, a small OS-abstraction helper library (thread/time/memory/map/trace wrappers from `common/src`) used by enclave-runtime (uRTS/enclave_common) and simulation targets.

## Packaging mapping

- `libsgx-headers` package is defined by:
  - [`../build_infrastructure/linux/installer/common/libsgx-headers/BOMs/libsgx-headers.txt`](../build_infrastructure/linux/installer/common/libsgx-headers/BOMs/libsgx-headers.txt)
  - This exports a runtime-facing subset from `common/inc/`.
- The full SDK installer/header set includes additional files from `common/inc/` via:
  - [`../build_infrastructure/linux/installer/common/sdk/BOMs/sdk_base.txt`](../build_infrastructure/linux/installer/common/sdk/BOMs/sdk_base.txt)

## Build-time usage

**High-level Overview:** `inc/` is the shared header surface, `inc/internal/` is in-tree implementation support, and `src/` is shared implementation code.

- SDK-side makefiles include `common/inc` and `common/inc/internal`, and build artifacts such as `sgx_sign`, `libsgx_dh.a`, `libsgx_ptrace.so`, and simulation artifacts (e.g. `libsgx_urts_sim.so`, `libsgx_trts_sim.a`) pull sources from `common/src`.
- Enclave-runtime build artifacts (e.g. `libsgx_urts.so`, `liburts_internal.so`, `libsgx_enclave_common.so`) consume headers from `common` (`common/inc` and internal headers where needed), and `libsgx_urts.so` also pulls sources from `common/src`.
