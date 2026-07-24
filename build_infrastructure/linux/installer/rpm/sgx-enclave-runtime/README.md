# sgx-enclave-runtime RPM packaging

This directory builds the RPM packages for the SGX **enclave runtime** and its
developer files:

- `libsgx-enclave-common`, `libsgx-urts` - runtime libraries needed to load and run enclaves
- `libsgx-enclave-common-devel`, `libsgx-headers` - headers and link-time symlinks for building against them

Unlike the standalone per-package builds, this uses a **single spec** that produces the four
runtime packages above from one source tarball and one `%build`, plus two dependency-only
meta-packages (`sgx-enclave-runtime`, `sgx-enclave-runtime-devel`) that pull them in -
keeping the runtime components versioned and released together.

Files:

- `sgx-enclave-runtime.spec.tmpl` - RPM spec template; `@enclave_runtime_version@` is substituted at build time
- `build.sh` - stages a build tree, fills in the spec, builds the upstream tarball and the RPMs
- `clean.sh` - removes generated `*.rpm`, `*.tar.gz` and `*.spec.in`
- `sanitize.sh` - produces a clean source tarball from the BOM (used for source releases)

## Prerequisites

- `rpmbuild` (>= 4.12 recommended) and the spec's `BuildRequires`.
- The runtime libraries are built first; the spec compiles them from the bundled
  source tarball during the RPM `%build` step.

## Usage

```sh
./build.sh     # build the RPMs into this directory
./clean.sh     # remove build artifacts
```

The package version defaults to the product version in `common/inc/internal/se_version.h`,
and can be overridden:

```sh
ENCLAVE_RUNTIME_VERSION=1.2.3 ./build.sh
```

The resulting `*.rpm` and `*.src.rpm` are copied into this directory.
