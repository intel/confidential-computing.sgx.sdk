# `sdk/`

Source for the Intel&reg; Software Guard Extensions Software Development Kit (Intel&reg; SGX SDK): the trusted in-enclave libraries and runtime, the untrusted host-side helper libraries, and the build/signing toolchain.

For repository context and build instructions see [../README.md](../README.md).

## API and developer documentation

The SDK APIs and programming model are comprehensively covered by the official Intel documentation:

- [Intel&reg; SGX Developer Guide for Linux](https://download.01.org/intel-sgx/latest/linux-latest/docs/Intel_SGX_Developer_Guide_for_Linux.pdf) — enclave lifecycle, memory model, sealing, attestation, EDL authoring, simulation mode, and porting guidance.
- [Intel&reg; SGX Developer Reference for Linux](https://download.01.org/intel-sgx/latest/linux-latest/docs/Intel_SGX_Developer_Reference_for_Linux_OS.pdf) — full API reference: `sgx_edger8r`, trusted (`trts`) and untrusted (`urts`) APIs, cryptographic primitives, protected FS, switchless calls, etc.

## What this source tree builds

The SDK builds as a self-contained **binary installer** (`sgx_linux_x64_sdk_<version>.bin`) that installs into a directory of your choice (e.g. `/opt/intel/sgxsdk`). It is not distributed as individual `.deb`/`.rpm` packages. See [../README.md#install-the-intel-sgx-sdk](../README.md#install-the-intel-sgx-sdk) for installation instructions.

The installer bundles:

- **Trusted-side libraries** — linked into the enclave image at build time: e.g. `libsgx_trts.a`, `libsgx_tservice.a`, `libsgx_tcrypto.a`, `libtlibc.a`, `libtlibcxx.a`, and related trusted components.
- **Untrusted-side libraries** — linked into the host application: e.g. `libsgx_utls.a`, `libsgx_uswitchless.a`, `libsgx_uprotected_fs.a`, `libsgx_capable.so`, and related untrusted helpers.
  - The SDK also includes deploy-ABI shims[^deploy-shims] for [`libsgx_urts.so`](../enclave_runtime/urts/), [`libsgx_quote_ex.so`](https://github.com/intel/confidential-computing.sgx/tree/main/psw/uae_service/linux/libsgx_quote_ex.lds), and (legacy[^uae-legacy]) [`libsgx_uae_service.so`](https://github.com/intel/confidential-computing.sgx/tree/main/psw/uae_service/linux/uae_service.lds) (as well as `_sim` variants of these libs — see below).
- **Tools** — `sgx_edger8r` (Enclave Definition Language (EDL) stub generator), `sgx_sign` (enclave signer), `sgx_encrypt` (Protected Code Loader (PCL) encryption tool).
- **Simulation libraries** — software-only counterparts (`libsgx_trts_sim.a`, `libsgx_urts_sim.so`, `libsgx_quote_ex_sim.so`, etc.) used to build and run enclaves without SGX hardware.
- **Headers** — installed under `include/`; public SDK headers used when compiling enclaves and host applications.
- **Sample source code** — bundled under `SampleCode/` as compilable source (not prebuilt binaries); see [../SampleCode/](../SampleCode/) and [../README.md#sample-applications](../README.md#sample-applications).

[^uae-legacy]: `libsgx_uae_service.so` / [`sgx_uae_service.h`](../common/inc/sgx_uae_service.h) is a deprecated umbrella API for AESM (Architectural Enclave Service Manager) services; prefer functionality-specific APIs via AESM plugins (functionality bundles), e.g., `libsgx_quote_ex.so` / [`sgx_uae_quote_ex.h`](../common/inc/sgx_uae_quote_ex.h) (or its [DCAP counterpart](https://github.com/intel/confidential-computing.tee.dcap/tree/main/QuoteGeneration/quote_wrapper/ql)) for quoting _(the functionality is provided by `libsgx-aesm-quote-ex-plugin` DEB/RPM package AESM-side)_.[^legacy-le-status]

[^legacy-le-status]: Launch-Enclave (LE) / whitelist launch-control APIs in [`sgx_uae_launch.h`](../common/inc/sgx_uae_launch.h) are deprecated; `libsgx_launch.so` / `libsgx_launch_sim.so` have been removed since v2.28. Flexible Launch Control (FLC) via the in-kernel SGX driver is the recommended mechanism.

[^deploy-shims]: `urts`/`quote_ex`/`uae_service` SDK entries are built from `*_deploy.c` sources and act as ABI-compatibility shims (they're hollow and only print guidance to use the Intel&reg; SGX PSW (Platform Software) runtime libraries).


## Simulation mode

Simulation mode (`SGX_MODE=SIM`) replaces the SGX hardware instructions with software emulation. It allows development and testing on machines without SGX support and does **not** provide any security guarantees. Hardware mode (`SGX_MODE=HW`, the default) requires a real SGX-capable CPU and driver. See the [Developer Guide](https://download.01.org/intel-sgx/latest/linux-latest/docs/Intel_SGX_Developer_Guide_for_Linux.pdf) for a detailed comparison.

## Make targets and build flavors

Building and packaging are driven from the repository root — see [../README.md#build-the-intel-sgx-sdk](../README.md#build-the-intel-sgx-sdk) for the full workflow. The entry point is `make sdk` (with mitigation variants) or `make sdk_install_pkg` to produce the installer.

> [!NOTE]
>  [`Makefile`](Makefile) in this directory is **self-contained for a single build pass**: it includes [`Makefile.source`](Makefile.source) (which lists every SDK component to compile) and can be invoked directly, e.g.:
>
> ```bash
> make -C sdk/
> ```
>
> In default compilation mode, the top-level [`../Makefile`](../Makefile) calls it **three times** (clean between each) to produce all three mitigation flavors for CVE-2020-0551: `LOAD`, `CF`, and `none`.

> [!TIP]
> Invoking the top-level `make preparation` target is required before the first build, to fetch prebuilts, initialize submodules, and apply patches.
>

Mitigation behavior is controlled by `MITIGATION-CVE-2020-0551`; SDK library/toolchain combinations are controlled by `USE_OPT_LIBS`; and installer packaging variants are exposed by top-level `sdk_install_pkg`, `sdk_install_pkg_no_mitigation`, and `sdk_install_pkg_from_source` targets. See [../README.md#build-the-intel-sgx-sdk](../README.md#build-the-intel-sgx-sdk) for details.
