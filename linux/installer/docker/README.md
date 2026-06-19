# Deploy SGX enclaves in containers

Build and run the Intel(R) SGX SDK samples in Docker containers. The [Dockerfile](Dockerfile) **downloads** prebuilt SGX packages from the Intel SGX repo on 01.org; it never builds the SDK/PSW from source. (Its sibling [docker/build](../../../docker/build) self-compiles instead.)

## Quick start

**Prerequisites:** [Docker and Compose](https://docs.docker.com/), and an SGX host using the in-kernel driver (Linux 5.11+, exposes `/dev/sgx_enclave`). No SGX hardware? Build for simulation with `SGX_MODE=SIM`. Older kernel or out-of-tree driver? See [Legacy Launch Control driver](#legacy-launch-control-driver-and-kernel-for-sgx).

Build and run the default sample (`SampleEnclave`) with Compose:

```
$ ./build_compose_run.sh
```

Pick a different sample with `SAMPLE_NAME`, or build for simulation with `SGX_MODE`:

```
$ SAMPLE_NAME=SealUnseal ./build_compose_run.sh
$ SGX_MODE=SIM ./build_compose_run.sh
```

Valid samples: `Cxx11SGXDemo`, `Cxx14SGXDemo`, `Cxx17SGXDemo`, `LocalAttestation`, `PowerTransition`, `ProtobufSGXDemo`, `SampleAEXNotify`, `SampleCommonLoader`, `SampleEnclave`, `SampleEnclaveGMIPP`, `SampleEnclavePCL`, `SealUnseal`, `Switchless`, `SampleAttestedTLS`.

### Run with Docker directly

Compose is the simplest path. To run the sample (and, for out-of-process quoting, the AESM) as separate `docker run`s in two terminals instead:

```
$ ./build_and_run_aesm_docker.sh      # terminal 1: AESM sidecar (only for quoting samples)
$ ./build_and_run_sample_docker.sh    # terminal 2: the sample
```

A non-quoting sample such as `SampleEnclave` needs only the second.

## Customization options

The run scripts (`build_compose_run.sh`, `build_and_run_sample_docker.sh`) and `docker-compose.yml` read these environment variables. Each has a per-sample default, so for the stock samples you can leave them all unset. Impossible combinations (unknown sample/provider/mode, quoting under `SGX_MODE=SIM`, or an out-of-process provider with `USE_AESM=0`) are rejected up front.

- `SAMPLE_NAME` — which [`SampleCode/`](../../../SampleCode) sample to build and run (default `SampleEnclave`; full list above).
- `SGX_MODE` — `HW` (default) or `SIM` to build the simulation runtime, which runs on any host with no SGX hardware, driver or AESM.
- `QUOTE_PROVIDER` — the sample's quoting flavour. Only `SampleAttestedTLS` does attestation; every other in-scope sample is `none`.
  - `none` — plain SGX SDK sample, no remote-attestation quote.
  - `dcap_in_proc` — DCAP / ECDSA (QE3) quoting with PCE/QE3 loaded *in* the sample process (no AESM). Default for `SampleAttestedTLS` under `build_and_run_sample_docker.sh`.
  - `dcap_aesm` — DCAP / ECDSA quoting produced *out-of-process* by the AESM. Default for `SampleAttestedTLS` under Compose (it can stand up the AESM itself).
  - `aesm_universal` — EPID / "universal" quoting, always out-of-process via the AESM. Supported by the AESM image but not exercised by the in-scope samples.
- `COLLATERAL_PROVIDER` — where DCAP fetches PCK collateral (default `none` without quoting, else `pccs-host`). Selects the QCNL config; a PCS/PCCS API subscription key is out of scope.
  - `none` — no Quote Provider Library (plain samples).
  - `pcs` — the public Intel Provisioning Certification Service.
  - `pccs-host` — a PCCS reachable on the Docker host (`PCCS_HOST_URL`).
  - `pccs-container` — a sibling `pccs` container at `https://pccs:8081/`.
  - **Note**: The `pccs-*` options both point at an existing PCCS; scripts herein do not ship PCCS service/compose of their own. To stand one up, see Intel's [PCCS container](https://github.com/intel/confidential-computing.tee.dcap.pccs/tree/main/service/container) build/run guide.
- `INSTALL_DCAP_QVL` — install the [DCAP](https://github.com/intel/confidential-computing.tee.dcap) Quote Verification Library (verify a peer quote). Default `1` for `SampleAttestedTLS`, else `0`.
- `SAMPLE_EXTRA_RUNTIME_PACKAGES` — extra non-SGX apt packages a sample needs to *run* (space-separated). Default `make` for `SampleAttestedTLS`, empty otherwise.
- `USE_AESM` — bring up / attach the AESM. Defaults to `1` when `QUOTE_PROVIDER` is out-of-process (`aesm_universal` / `dcap_aesm`), else `0`. Also required for the [legacy Launch Enclave driver](#legacy-launch-control-driver-and-kernel-for-sgx).

## Dockerfile

The [Dockerfile](Dockerfile) is multi-stage and **downloads** prebuilt SGX packages from 01.org (it never compiles the SDK/PSW). The run scripts drive it; the build-args below are for direct or advanced use.

### Docker build flavors

Two stages are meant to be built as `--target`; the rest are shared or intermediate:

- `sgxbase` *(base)* — Ubuntu 22.04 plus the Intel SGX APT repo (the live 01.org repo, or a staged local one). Shared by every other stage.
- `build_env` *(intermediate)* — `sgxbase` + `build-essential` + the SGX SDK. Sample-independent, so it caches once and is reused across all samples and modes.
- `sgx_sample_builder` *(intermediate)* — builds `SAMPLE_NAME` and stages its runtime artifacts into a clean tree.
- **`sample`** *(target)* — the runnable sample image: runtime SGX libraries + staged artifacts, run as an unprivileged user.
- **`aesm`** *(target)* — the AESM sidecar image, used out-of-process by quoting samples.

#### Build-args

Every knob is a `--build-arg` with a per-sample default supplied by the run scripts, so for the stock samples you can leave them unset. The provider knobs share the semantics from [Customization options](#customization-options).

| Build-arg | Default | Stage(s) | Purpose |
|---|---|---|---|
| `SGX_VERSION` | *(empty)* | `sgxbase`, `build_env` | Pin the whole SGX stack to one 01.org release (e.g. `2.29`); empty tracks the rolling `latest`. |
| `SAMPLE_NAME` | `SampleEnclave` | `sgx_sample_builder`, `sample` | Which `SampleCode/` sample to build and run. |
| `SGX_MODE` | `HW` | `sgx_sample_builder` | `HW`, or `SIM` for the simulation runtime (no SGX hardware/driver). |
| `SGX_DEBUG` | `0` | `sgx_sample_builder` | SGX debug build flag passed to the sample's `make`. |
| `SGX_PRERELEASE` | `1` | `sgx_sample_builder` | SGX pre-release build flag passed to the sample's `make`. |
| `QUOTE_PROVIDER` | `none` | `sample`, `aesm` | Quoting stack: `none` / `aesm_universal` / `dcap_in_proc` / `dcap_aesm`. |
| `INSTALL_DCAP_QVL` | `0` | `sample` | Install the DCAP Quote Verification Library (verify a peer quote). |
| `INSTALL_DCAP_QPL` | `0` | `sample`, `aesm` | Install the DCAP Quote Provider Library (fetch PCK collateral from a PCCS). |
| `COLLATERAL_PROVIDER` | `pccs-host` | `sample`, `aesm` | QCNL config activated when the QPL is installed: `pcs` / `pccs-host` / `pccs-container`. |
| `PCCS_HOST_URL` | `https://host.docker.internal:8081/...` | `sample`, `aesm` | PCCS endpoint baked into the `pccs-host` QCNL config. |

##### Using local prebuilts

To use locally staged SGX artifacts instead of downloading from 01.org, export these environment variables before calling the run scripts. They are **shell script inputs**, not `--build-arg`s — the scripts stage the referenced files into `_sgx_local_artifacts/` and the Dockerfile picks them up from there.

- `SGX_OVERRIDE_SDK_INSTALLER_PATH` — host path to an SDK installer (`sgx_linux_x64_sdk_*.bin`), used instead of downloading from the `SGX_VERSION` release tree.
- `SGX_OVERRIDE_LOCAL_REPO_TGZ_PATH` — host path to a `sgx_debian_local_repo.tgz` (from 01.org distro dirs, or `make deb_local_repo`), used instead of the live 01.org APT repo. The `SGX_VERSION` apt pin is skipped automatically (the tgz already pins versions).

### Compose stack and profiles

`docker-compose.yml` defines the multi-container stack that `build_compose_run.sh` drives. The script resolves the knobs above, picks a Compose profile from `SGX_MODE` / `QUOTE_PROVIDER` / `USE_AESM`, and exports the host SGX group GIDs (`SGX_GID` / `SGX_PRV_GID`, dynamic per host) before `docker compose up`. It targets the in-kernel driver (`/dev/sgx_enclave`, `/dev/sgx_provision`); for the legacy driver see [below](#legacy-launch-control-driver-and-kernel-for-sgx).

Profiles selected for the sample:
- `hw` + `aesm` — out-of-process quoting (`dcap_aesm` / `aesm_universal`): the `sample` service (`/dev/sgx_enclave` + `sgx` group) offloads quoting to the `aesm` sidecar over the shared socket (`SGX_AESM_ADDR`).
- `hw-inproc` — in-process quoting or non-quoting samples: the `sample-inproc` service also binds `/dev/sgx_provision` + the `sgx_prv` group and needs no AESM.
- `sim` — the `sample-sim` service: the simulation runtime is baked in, so it needs no SGX device, host group or AESM and runs anywhere.

`aesm-nodev` and `sim-aesm-client` exist only for non-SGX CI smoke tests (no real quoting).

### Standalone AESM container

`build_and_run_aesm_docker.sh` stands up the AESM on its own to back quoting samples (e.g. `SampleAttestedTLS`) out-of-process. It shares the build-args above with AESM-oriented defaults:
- `QUOTE_PROVIDER=dcap_aesm` — installs the AESM quote-ex plugin (which also serves `aesm_universal`); without it the AESM cannot produce a quote and a sample's RA-TLS certificate comes back null. Use `none` for a launch-token-only AESM.
- `INSTALL_DCAP_QPL=1` — an out-of-process AESM is what fetches PCK collateral, so the Quote Provider Library is on by default.
- `COLLATERAL_PROVIDER=pccs-host` — see [Customization options](#customization-options).

## Legacy Launch Control driver and kernel for SGX

Three driver generations exist, each with a different device node:

| Driver | Device node | Notes |
|---|---|---|
| In-kernel (Linux 5.11+) | `/dev/sgx_enclave`, `/dev/sgx_provision` | Recommended; Flexible Launch Control (FLC), requires an FLC-capable CPU. |
| [DCAP out-of-tree driver](https://github.com/intel/confidential-computing.tee.dcap/tree/DCAP_1.23/driver) *(archived, last: DCAP 1.23)* | <ul><li>`/dev/sgx_enclave`, `/dev/sgx_provision` (current; ≥ driver V1.41 / DCAP 1.23, matches in-kernel)</li><li>compat symlinks `/dev/sgx/enclave`, `/dev/sgx/provision`</li><li>`/dev/sgx` + `/dev/sgx_prv` on intermediate (V1.22) builds; single node `/dev/sgx` on very old (≤ V1.21) builds</li></ul> | Flexible Launch Control (FLC), requires an FLC-capable CPU. Use when the kernel is too old for the built-in driver. No longer maintained. |
| [Legacy Launch Control driver](https://github.com/intel/linux-sgx-driver) *(archived)* | `/dev/isgx` | Launch Enclave (LE)-based; does **not** require FLC; for pre-FLC hardware or very old kernels. No longer maintained. |

The scripts and Compose files target the in-kernel driver (or the DCAP out-of-tree driver, which uses the same device nodes). To use the **Legacy** Launch Control driver (`/dev/isgx`) instead, edit the device mappings:
1. In all three files (`docker-compose.yml`, `build_and_run_aesm_docker.sh`, `build_and_run_sample_docker.sh`): replace `/dev/sgx_enclave` with `/dev/isgx`.
2. In all three files: also **remove** every `/dev/sgx_provision` reference (the legacy driver exposes no separate provisioning device).

**Note:** When switching drivers, uninstall the previous one and reboot before installing the other. The DCAP out-of-tree driver uses the same `/dev/sgx_enclave` / `/dev/sgx_provision` nodes as the in-kernel driver, so no remapping is needed. For the Legacy Launch Enclave (LE)-based driver (`/dev/isgx`), pin `SGX_VERSION=2.27` (or earlier) — PSW 2.28+ refuses to open it, and the LE-based code path was removed from the development tree in 2.28.
If you use an older DCAP OOT driver version that exposes `/dev/sgx` (single-node), current PSW still opens it, but the code path is marked for removal in the development tree and may stop functioning in a future release.

Pre-FLC hardware (`/dev/isgx`) relies on the AESM for the Launch Enclave, so set `USE_AESM=1`. 

The `aesm_universal` provider (quoting via the AESM; ECDSA-only since v2.27, when the EPID plugin was dropped) is not used by any current sample — it was last exercised by the [deprecated](https://github.com/intel/confidential-computing.sgx/releases/tag/sgx_2.28) `RemoteAttestation` sample, which demonstrated the universal key-exchange API with both ECDSA and EPID (the latter [retired with IAS](https://community.intel.com/t5/Intel-Software-Guard-Extensions/IAS-End-of-Life-Announcement/td-p/1545831)), last shipped in [sgx_2.27](https://github.com/intel-innersource/frameworks.security.confidential-computing.sgx/tree/sgx_2.27/SampleCode/RemoteAttestation) and no longer supported. The scripts still accept `aesm_universal` mode, should someone need to test a legacy application, using ECDSA quoting via the "legacy" (universal) path.

