Intel&reg; Software Guard Extensions SDK for Linux\* OS
=====================================================

- [Intel® Software Guard Extensions SDK for Linux\* OS](#intel-software-guard-extensions-sdk-for-linux-os)
  - [Introduction](#introduction)
  - [Repository layout](#repository-layout)
  - [License](#license)
  - [Contributing](#contributing)
  - [Documentation](#documentation)
  - [Downloads](#downloads)
  - [Quick Start](#quick-start)
    - [Containerized sample bring-up](#containerized-sample-bring-up)
  - [Supported Operating Systems](#supported-operating-systems)
  - [Building](#building)
    - [Prerequisites](#prerequisites)
    - [Build the Intel® SGX SDK](#build-the-intel-sgx-sdk)
    - [Build the Intel® SGX Enclave Runtime Packages](#build-the-intel-sgx-enclave-runtime-packages)
  - [Installation](#installation)
    - [Install the Intel® SGX SDK](#install-the-intel-sgx-sdk)
    - [Install the Intel® SGX Enclave Runtime Packages](#install-the-intel-sgx-enclave-runtime-packages)
    - [Test the Intel® SGX SDK Package with the Code Samples](#test-the-intel-sgx-sdk-package-with-the-code-samples)
    - [Compile and Run the Code Samples in the Hardware Mode](#compile-and-run-the-code-samples-in-the-hardware-mode)
  - [Reproducibility](#reproducibility)


Introduction
------------
Intel&reg; Software Guard Extensions (Intel&reg; SGX) is an Intel technology for application developers seeking to protect select code and data from disclosure or modification.

This repository hosts the Intel&reg; SGX SDK and the Intel&reg; SGX enclave runtime for Linux\*. It provides the trusted and untrusted libraries, the build and signing tools (`sgx_edger8r`, `sgx_sign`, ...), the untrusted runtime system (`urts`) and the enclave-common loader API, and a set of [code samples](SampleCode). It is part of the [confidential-computing.sgx](https://github.com/intel/confidential-computing.sgx) project: it is consumed there as the `sdk` submodule, and it also builds on its own.

> [!NOTE]
> ### :jigsaw: This repository is the extracted Intel<sup>&reg;</sup> SGX SDK
> 
> Starting with [release 2.30](https://github.com/intel/confidential-computing.sgx/releases/tag/sgx_2.30), the _SDK_ (including _samples_) and the SGX _enclave runtime_ libraries were split out of the consolidated [:octocat: confidential-computing.sgx](https://github.com/intel/confidential-computing.sgx) project (previously under `sdk/` and `psw/`) and are vendored back there as the `sdk` submodule.[^sdk-split]
>  - The `sdk-extraction-2.30` *tag* captures the same source state ([ :label:  SGX](https://github.com/intel/confidential-computing.sgx/tree/sdk-extraction-2.30) ↔ [:label:  SGX SDK](https://github.com/intel/confidential-computing.sgx.sdk/tree/sdk-extraction-2.30)) at split.

[^sdk-split]: This is a source-layout change only: the consolidated build is unchanged and the released packages, installers and download locations are not affected.

The Intel&reg; SGX SDK for Windows\* is published separately, through [NuGet](https://www.nuget.org/packages/Intel.SGX.SDK) and the Intel Download Center; this repository tracks the Linux\* sources.

<a id="note-driver"></a>

> [!NOTE]
> The Linux\* kernel [includes the SGX driver](https://docs.kernel.org/arch/x86/sgx.html) since mainline release [`5.11`](https://git.kernel.org/torvalds/c/5583ff677b3108cde989b6d4fd1958e091420c0c) — no separate driver installation is needed on modern kernels. Device nodes are at `/dev/{sgx_enclave, sgx_provision}`. The platform must support and have [Flexible Launch Control](https://cc-enabling.trustedservices.intel.com/intel-sgx-sw-installation-guide-linux/02/installation_instructions/#driver-installation) configured.

**Related Projects**

The [confidential-computing.sgx](https://github.com/intel/confidential-computing.sgx) project assembles this SDK repository with the Intel&reg; SGX PSW, packaging, and reproducibility tooling. See its [Quick Start](https://github.com/intel/confidential-computing.sgx#quick-start) for end-to-end stack bring-up and its [installation guidance](https://github.com/intel/confidential-computing.sgx#installation) when you need the full software stack rather than just the SDK.

The [intel-sgx-ssl](https://github.com/intel/intel-sgx-ssl) project provides a full-strength general purpose cryptography library for Intel&reg; SGX enclave applications. It is based on the underlying OpenSSL* Open Source project. Intel&reg; SGX SDK provides a [build combination](#build-the-intel-sgx-sdk) to build out a SGXSSL-based SDK. Users can also use this cryptography library in SGX enclave applications separately.

<a id="dcap-samples"></a>

The [Intel&reg; SGX Data Center Attestation Primitives (DCAP)](https://github.com/intel/confidential-computing.tee.dcap) project provides libraries and tools for ECDSA-based remote attestation. For concrete remote-attestation examples, start with the `QuoteGenerationSample` and `QuoteVerificationSample` in the DCAP repository's [`SampleCode/`](https://github.com/intel/confidential-computing.tee.dcap/tree/main/SampleCode).

Repository layout
-----------------
- [`sdk/`](sdk/) — the Intel&reg; SGX SDK: the trusted runtime and libraries (`trts`, `tlibc`, `tlibcxx`, `tlibcrypto`, `tservice`, `tprotected_fs`, ...), untrusted helper libraries, and the host tools (`sgx_edger8r`, `sgx_sign`, `sgx_encrypt`, ...).
- [`enclave_runtime/`](enclave_runtime/) — enclave runtime (launch) components of Intel&reg; SGX Platform Software (PSW): the untrusted runtime system (`urts`) and the enclave-common loader API (`enclave_common`).
- [`SampleCode/`](SampleCode/) — sample enclaves and host applications.
- [`common/`](common/) — shared headers and support code, including SGX API headers in `common/inc/`; the runtime-facing subset is provided by the `libsgx-headers` DEB/RPM package.
- [`external/`](external/) — third-party dependencies consumed as submodules (IPP crypto, protobuf/abseil, OpenMP, libcxxrt, cbor, SGX EMM, ...).
- [`build_infrastructure/`](build_infrastructure/) — packaging, installer and reproducibility scripts, including Docker container build helpers.


License
-------
See [License.txt](License.txt) for details.

Contributing
-------
See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

For questions and general discussion, the [Intel&reg; SGX community forum](https://community.intel.com/t5/Intel-Software-Guard-Extensions/bd-p/software-guard-extensions) is a good place to start.

Documentation
-------------
- [Intel&reg; SGX for Linux\* OS](https://www.intel.com/content/www/us/en/developer/tools/software-guard-extensions/linux-overview.html) project home page on [Intel Developer Zone](https://www.intel.com/content/www/us/en/developer/overview.html)
- [Intel&reg; Confidential Computing Enabling documentation](https://cc-enabling.trustedservices.intel.com/)
- [Intel&reg; SGX for Linux\* OS — release documents](https://download.01.org/intel-sgx/latest/linux-latest/docs/)
  - [Developer Guide](https://download.01.org/intel-sgx/latest/linux-latest/docs/Intel_SGX_Developer_Guide_for_Linux.pdf) — enclave design patterns, sealing, attestation concepts
  - [Developer Reference](https://download.01.org/intel-sgx/latest/linux-latest/docs/Intel_SGX_Developer_Reference_for_Linux_OS.pdf) — SDK/EDL API reference (edger8r, trts/urts)
- Intel&reg; SGX Programming Reference[^sgx-progref]
  - [SDM Vol 3D: System Programming Guide, Part 4](https://www.intel.com/content/www/us/en/content-details/916745/intel-64-and-ia-32-architectures-software-developer-s-manual-volume-3d-system-programming-guide-part-4.html) — SGX architecture, data structures, ENCLS/ENCLU leaf function reference
  - [SDM Vol 2: Instruction Set Reference](https://www.intel.com/content/www/us/en/content-details/916605/intel-64-and-ia-32-architectures-software-developer-s-manual-combined-volumes-2a-2b-2c-and-2d-instruction-set-reference-a-z.html) — ENCLS/ENCLU instruction opcode encoding

[^sgx-progref]: The [original standalone doc (329298)](https://www.intel.com/content/dam/develop/external/us/en/documents/329298-002-629101.pdf) has been absorbed into the Intel&reg; Software Developer's Manual (SDM); the two SDM volumes above are the current authoritative references.

Downloads
---------
Pre-built packages and the SDK installer binary for Linux are published on [01.org](https://download.01.org/intel-sgx/latest/linux-latest/) as part of the [confidential-computing.sgx](https://github.com/intel/confidential-computing.sgx) release:
- [Intel&reg; SGX PSW and SDK](https://download.01.org/intel-sgx/latest/linux-latest/) — distro packages and the SDK installer binary
- [Intel&reg; SGX DCAP](https://download.01.org/intel-sgx/latest/dcap-latest/linux/) — quoting and verification libraries

For package repository setup, package-signing details, and Windows* distribution notes, see the consolidated repository's [Downloads](https://github.com/intel/confidential-computing.sgx#downloads) section.

Quick Start
-----------

Choose the path that matches your goal:

- **Build and install the SDK locally** — follow [Build the Intel&reg; SGX SDK](#build-the-intel-sgx-sdk) and [Install the Intel&reg; SGX SDK](#install-the-intel-sgx-sdk), then run the [sample code tests](#test-the-intel-sgx-sdk-package-with-the-code-samples) or [hardware-mode samples](#compile-and-run-the-code-samples-in-the-hardware-mode).
- **Bring up the full Intel&reg; SGX software stack** — if you also need the PSW, AESM, package repositories, or Docker-based flows, start from the consolidated repository's [Quick Start](https://github.com/intel/confidential-computing.sgx#quick-start).

### Containerized sample bring-up

For a single sample-enclave bring-up in Docker, this repository includes two containerized paths:

- **Build-and-run from source** — [build_infrastructure/docker/build/README.md](build_infrastructure/docker/build/README.md) builds the SDK installer and enclave runtime packages from this repository, then builds and runs `SampleEnclave` in a container.
- **Download-and-run from published packages** — [build_infrastructure/linux/installer/docker/README.md](build_infrastructure/linux/installer/docker/README.md) downloads a released SDK installer and installs the published `libsgx-urts` runtime package before building and running `SampleEnclave` in a container.

Supported Operating Systems
---------------------------
The following Linux\* distributions are supported for both building and installing the Intel&reg; SGX SDK and enclave runtime:

- Ubuntu\* 22.04, 24.04, and 26.04 LTS Server 64-bit
- Red Hat Enterprise Linux Server 9.4 and 10.0 64-bit
- CentOS Stream 9 and 10 64-bit
- SUSE Linux Enterprise Server 15.6 64-bit
- Anolis OS 8.10 64-bit
- Azure Linux 3.0 64-bit
- Debian 10 and 12 64-bit


Building
--------
### Prerequisites
- Ensure that you have one of the [supported operating systems](#supported-operating-systems).

- Use the following command(s) to install the required tools to build the Intel&reg; SGX SDK:
  * On Debian 10 and Debian 12:
    ```bash
    sudo apt-get install build-essential ocaml ocamlbuild automake autoconf \
        libtool wget python3 libssl-dev git cmake perl
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    ```
  * On Ubuntu 22.04, Ubuntu 24.04, and Ubuntu 26.04:
    ```bash
    sudo apt-get install build-essential ocaml ocamlbuild automake autoconf \
        libtool wget python-is-python3 libssl-dev git cmake perl
    ```
  * On Red Hat Enterprise Linux 9.4 and 10.0:
    ```bash
    sudo yum groupinstall 'Development Tools'
    sudo yum install ocaml ocaml-ocamlbuild wget python3 openssl-devel git cmake perl
    ```
  * On CentOS Stream 9 and 10, and Azure Linux 3.0:
    ```bash
    sudo dnf group install 'Development Tools'
    sudo dnf install ocaml ocaml-ocamlbuild redhat-rpm-config openssl-devel \
        wget rpm-build git cmake perl python3
    ```
  * On Anolis OS 8.10:
    ```bash
    sudo dnf group install 'Development Tools'
    sudo dnf --enablerepo=powertools install ocaml ocaml-ocamlbuild \
        redhat-rpm-config openssl-devel wget rpm-build git cmake perl python3
    sudo alternatives --set python /usr/bin/python3
    ```
  * On SUSE Linux Enterprise Server 15.6:
    ```bash
    sudo zypper install --type pattern devel_basis
    sudo zypper install ocaml ocaml-ocamlbuild automake autoconf libtool wget \
        python3 libopenssl-devel rpm-build git cmake perl
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    ```
  > ℹ️ **Note:** To build the Intel&reg; SGX SDK, gcc 7.3+ and glibc 2.27+ are required.

- Clone this repository and prepare the submodules and prebuilt binaries:
  ```bash
  git clone --recurse-submodules \
      https://github.com/intel/confidential-computing.sgx.sdk.git sgx-sdk
  cd sgx-sdk && make preparation
  ```
  `make preparation` initialises git submodules, applies patches, and runs `build_infrastructure/download_prebuilt.sh` to fetch prebuilt binaries.
  If you prefer to initialise submodules manually, do so before running `make preparation`:
  ```bash
  git submodule update --init --recursive
  ```

  > 💡 **Tip:** `download_prebuilt.sh` uses `wget` to fetch over the network. If you are behind a proxy, set the relevant proxy variables first, e.g.:
  > ```bash
  > export https_proxy=http://proxy:port
  > export no_proxy=localhost,127.0.0.1
  > ```

  > ℹ️ **Note:** When pulling a new release, run `make distclean` first if patched submodules changed — this avoids patch conflicts (`error: Your local changes to the following files would be overwritten by checkout`).
  > **Caution:** this deletes all submodule working trees; commit any local changes first.
  > ```bash
  > make distclean
  > ```

- *(Debian 10 only)* The system `binutils` on Debian 10 lack mitigation options support. Copy the patched tools downloaded by `make preparation` to `/usr/local/bin`:
  ```bash
  sudo cp external/toolset/debian10/* /usr/local/bin
  ```
  Repeat after any update to ensure the latest versions are used.


### Build the Intel&reg; SGX SDK
> [!NOTE]
> After pulling a new release, run `make distclean` and `make preparation` again to update changed submodules.

- To build the Intel&reg; SGX SDK with the default configuration:
  ```bash
  make sdk
  ```
  `make sdk` runs three sequential sub-make passes with `MITIGATION-CVE-2020-0551` set to `LOAD`, `CF`, and unset, producing a full set of mitigation variants in `build/`.

  Key build variables (passed as `make <target> VAR=value`):

  | Variable | Default | Effect |
  |---|---|---|
  | `USE_OPT_LIBS` | `1` | Crypto library choice (see below) |
  | `DEBUG` | `0` | Set to `1` to include debug symbols |

  <br>

  `USE_OPT_LIBS` combinations:

  - | Value | Crypto |
    |---|---|
    | `0` | SGXSSL *(:warning: this flavor is deprecated)* |
    | `1` *(default)* | IPP |

    To use a **non-default** crypto combination:
    ```bash
    make sdk USE_OPT_LIBS=0
    ```
    <!-- DOC_MAINTENANCE: Remove the USE_OPT_LIBS=2/3 note in the future, after a few release cycles (i.e., v2.32++) -->
    > ℹ️ **Note:**
    > `USE_OPT_LIBS=2` and `USE_OPT_LIBS=3` (using the prebuilt "optimized" Intel string/math libraries) have been **removed**.
    > The last release to support them is [**2.29**](https://github.com/intel/confidential-computing.sgx/releases/tag/sgx_2.29).
    > Passing either value now aborts the build with an error.
    >
    > Use `USE_OPT_LIBS=0` (SGXSSL) or `USE_OPT_LIBS=1` (IPP); both build the open-sourced string/math libraries.
    >
    > - **Caution:**  `USE_OPT_LIBS=0` flavor (OpenSSL-based) is **deprecated**.
    >   Support is planned to be removed in an upcoming release.
    >   Consider migrating to the default (IPP-based) variant.

- To build without CVE-2020-0551 mitigations (single pass):
  ```bash
  make sdk_no_mitigation
  ```

- To build the Intel&reg; SGX SDK with debug information:
  ```bash
  make sdk DEBUG=1
  ```

- To clean the files generated by a previous `make sdk`:
  ```bash
  make clean
  ```
- To build and package the SDK installer:
  ```bash
  make sdk_install_pkg
  ```
  `sdk_install_pkg` depends on `sdk`, so it runs all three mitigation-mode passes automatically before packaging. The result is a **single** `.bin` installer (`sgx_linux_x64_sdk_${version}.bin` under `build_infrastructure/linux/installer/bin/`) that bundles all three mitigation variants (LOAD, CF, none). There is no need to run `make sdk` separately first.

  To include debug symbols in the installer:
  ```bash
  make sdk_install_pkg DEBUG=1
  ```
  For a no-mitigation-only installer:
  ```bash
  make sdk_install_pkg_no_mitigation
  ```

### Build the Intel&reg; SGX Enclave Runtime Packages

The SGX enclave runtime (`libsgx-urts`, `libsgx-enclave-common`) lives in `enclave_runtime/` and is packaged here independently of the SDK installer. The consolidated repo ([confidential-computing.sgx](https://github.com/intel/confidential-computing.sgx)) pulls these in automatically as part of `make deb_local_repo` / `make rpm_local_repo`.

- To build and package the enclave runtime (DEB — `libsgx-urts`, `libsgx-enclave-common`, `libsgx-headers`):
  ```bash
  make deb_sgx_sdk_pkg
  ```
  Or individually:
  ```bash
  make deb_libsgx_urts
  make deb_libsgx_enclave_common
  ```
- To build and package the enclave runtime (RPM):
  ```bash
  make rpm_sgx_sdk_pkg
  ```
  Or individually:
  ```bash
  make rpm_libsgx_urts
  make rpm_libsgx_enclave_common
  ```
- To build the runtime libraries only (without packaging):
  ```bash
  make enclave_runtime
  ```

Installation
------------

Before installing, ensure that:

- Your system runs one of the [supported operating systems](#supported-operating-systems).
- Install the runtime prerequisites for your distribution:
  * On Debian 10 and Debian 12:
    ```bash
    sudo apt-get install build-essential python3
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    ```
  * On Ubuntu 22.04, Ubuntu 24.04, and Ubuntu 26.04:
    ```bash
    sudo apt-get install build-essential python-is-python3
    ```
  * On Red Hat Enterprise Linux 9.4 and 10.0:
    ```bash
    sudo yum groupinstall 'Development Tools'
    sudo yum install python3
    ```
  * On CentOS Stream 9 and 10, and Azure Linux 3.0:
    ```bash
    sudo dnf group install 'Development Tools'
    sudo dnf install python3
    ```
  * On Anolis OS 8.10:
    ```bash
    sudo dnf group install 'Development Tools'
    sudo dnf install python3
    sudo alternatives --set python /usr/bin/python3
    ```
  * On SUSE Linux Enterprise Server 15.6:
    ```bash
    sudo zypper install --type pattern devel_basis
    sudo zypper install python3
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    ```

### Install the Intel&reg; SGX SDK
The `make sdk_install_pkg` build produces the installer at `build_infrastructure/linux/installer/bin/sgx_linux_x64_sdk_${version}.bin`. Install it as follows (the installer will prompt you to accept the license; adjust `--prefix` to your preferred location):
```bash
cd build_infrastructure/linux/installer/bin
./sgx_linux_x64_sdk_${version}.bin --prefix {SDK_INSTALL_PATH_PREFIX}
```

> [!NOTE]
> Set up the environment variables before compiling your code:
> ```bash
> source ${sgx-sdk-install-path}/environment
> ```

### Install the Intel&reg; SGX Enclave Runtime Packages
This repository also builds the SGX enclave runtime library packages ([`libsgx-urts`](enclave_runtime/urts), [`libsgx-enclave-common`](enclave_runtime/enclave_common)) and the accompanying development headers package ([`libsgx-headers`](build_infrastructure/linux/installer/common/libsgx-headers/BOMs/libsgx-headers.txt)).

For package repository setup, distro-specific install commands, upgrade guidance, and optional DCAP/AESM components, follow the consolidated repository's [Install the Intel&reg; SGX PSW](https://github.com/intel/confidential-computing.sgx#install-the-intel-sgx-psw)[^runtime-vs-psw] section. If you are bringing up remote attestation, use that guide together with the [DCAP samples](#dcap-samples) linked above.

[^runtime-vs-psw]: In the [consolidated repository](https://github.com/intel/confidential-computing.sgx), the runtime shared libraries (`libsgx_urts.so`, `libsgx_enclave_common.so`) are packaged with the Intel&reg; SGX Platform Software (PSW); here they are built directly from `enclave_runtime/`.

### Test the Intel&reg; SGX SDK Package with the Code Samples
- Compile and run each code sample in Simulation mode to verify the package:
  ```bash
  cd ${sgx-sdk-install-path}/SampleCode/LocalAttestation
  make SGX_MODE=SIM
  cd bin && ./app
  ```
  Use similar commands for other code samples.

### Compile and Run the Code Samples in the Hardware Mode
If you use an Intel SGX hardware enabled machine, you can run the code samples in hardware mode.
Ensure that your machine is running a Linux\* kernel with SGX driver support[^in-kernel-driver-info-note] and that the Intel&reg; SGX PSW is installed.
See the [confidential-computing.sgx](https://github.com/intel/confidential-computing.sgx) project for how to build and install the Intel&reg; SGX PSW.

[^in-kernel-driver-info-note]: The Linux\* kernel contains the necessary driver since the mainline kernel release `5.11`.

- Compile and run each code sample in hardware mode (debug build):
  ```bash
  cd ${sgx-sdk-install-path}/SampleCode/LocalAttestation
  make
  cd bin && ./app
  ```
  Use similar commands for other code samples.

  > ℹ️ **Note:** On Ubuntu 22.04 or any distro with systemd v248 or later, `/dev/sgx_enclave` is only accessible by users in the `sgx` group. Run the enclave application as a user in that group:
  > ```bash
  > # check systemd version:
  > systemctl --version
  > # add the sgx group to the user if v248 or above:
  > sudo usermod -a -G sgx <username>
  > ```


Reproducibility
-----------------------------------------
Intel&reg; SGX SDK binaries are built inside a reproducible Docker container to allow independent verification. To reproduce the build environment and verify the binaries, follow the [reproducibility README](build_infrastructure/linux/reproducibility/README.md).

Most binaries can be compared against a locally rebuilt output using the standard `diff` command. A reproducibly built SDK is also a prerequisite for reproducing the Architectural Enclave (AE) binaries in the [consolidated repository](https://github.com/intel/confidential-computing.sgx) — see that project's [reproducibility README](https://github.com/intel/confidential-computing.sgx/blob/main/linux/reproducibility/README.md) and [AE reproducibility verifier](https://github.com/intel/confidential-computing.sgx/blob/main/linux/reproducibility/ae_reproducibility_verifier/README.md) for details.
