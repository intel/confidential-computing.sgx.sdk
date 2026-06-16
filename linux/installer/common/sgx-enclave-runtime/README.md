# sgx-enclave-runtime install targets

This directory is a set of `make` install targets that stage the SGX
**enclave runtime** and its developer files into a destination tree:

- `libsgx-enclave-common`, `libsgx-urts` - runtime libraries needed to load and run enclaves
- `libsgx-enclave-common-devel`, `libsgx-headers` - headers and link-time symlinks for building against them

It only copies and lays out already-built artifacts. It does not compile anything.

## Prerequisites

- The runtime libraries are already built in `build/linux` (`libsgx_urts.so`,
  `libsgx_enclave_common.so`). From the source tree root, build them with the top-level
  Makefile:

  ```sh
  make preparation        # fetch submodules and prebuilts, apply patches
  make -C psw/urts/linux  # builds libsgx_urts.so and libsgx_enclave_common.so
  ```

  The developer headers under `common/inc` are part of the source tree (no build step).

- Host tools on `PATH`: `make`, `python3`, `gcc`, `awk` (plus coreutils: `install`, `readlink`).
  `dpkg-architecture` is used only to detect the Debian multiarch path; it is optional and
  silently skipped where absent.

  On Fedora these come from `make`, `python3`, `gcc`, `gawk`, and `coreutils`
  (all usually already installed); `dpkg-architecture` is Debian-only and not needed.

## Usage

```sh
make -C linux/installer/common/sgx-enclave-runtime install \
    SRCDIR=<path to source tree> \
    DESTDIR=<path to install into>
```

- `SRCDIR` - root of the source tree to read built libs and headers from. May be `.` when run from the repo root.
- `DESTDIR` - where the staged packages are written. This is the one you almost always want to set.

Targets:

- `install` (default) - runtime libraries and developer files
- `install-runtime` - runtime libraries only
- `install-dev` - headers and developer symlinks only
