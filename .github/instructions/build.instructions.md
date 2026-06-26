---
description: "Conventions for the Make/CMake build system, mitigation flavors, and packaging in the Intel SGX SDK."
applyTo: "**/Makefile,**/*.mk,**/*.cmake,**/CMakeLists.txt"
---
# Build system guidance

These are **suggestions** for changes to the build. The build is **Make‑first**;
CMake exists in a few in‑tree components (e.g. `sdk/tlibcxx`) and in some
`external/` dependencies, but the top‑level build flow is still driven by Make.
It is appropriate to add CMake support for new components, but don't break the existing Make‑first flow.
Top level make targets need to remain backward compatible.

## Conventions

- Keep shared flags in the central build env ([buildenv.mk](../../buildenv.mk) and
  `common/buildenv.mk`) rather than scattering compiler flags across component
  makefiles.
- Preserve the security/hardening flags already applied (stack protector, RELRO,
  `-z now`, non‑exec stack, fortify, CET where enabled). Don't silently weaken them.
- `make preparation` must remain the entry point that initializes submodules,
  applies `external/` patches, and fetches prebuilt dependencies — keep new setup
  steps wired through it. Make targets should be re‑entrant and support incremental
  and parallel builds. Where `make preparation` is a prerequisite, try to detect that
  it hasn't run and emit a clear error rather than failing obscurely.
- Respect the existing knobs instead of inventing parallel ones: `SGX_MODE`
  (`HW`/`SIM`), `DEBUG`, `USE_OPT_LIBS` (Intel IPP by default; the OpenSSL‑based
  SGXSSL path is legacy), and the `MITIGATION-CVE-2020-0551` flavors (`LOAD`, `CF`,
  or unset).

## Mitigation flavors

- The SDK builds in multiple CVE‑2020‑0551 mitigation flavors that land in separate
  output directories (`build/linux`, `build/linuxCF`, `build/linuxLOAD`). Changes
  that touch compilation should keep all flavors building, not just the default.
- Mitigation toggles interact with assembler/linker flags and prebuilt library
  paths; change them deliberately and keep the per‑flavor library selection
  consistent.

## Portability and packaging

- Support the documented toolchain range; gate newer compiler flags on version
  checks the way existing code does (some flags require newer GCC).
- Keep packaging format selection (DEB vs RPM) auto‑detected; allow an explicit
  override but don't hard‑code one distro.
- Prefer changes that keep the build reproducible; avoid embedding timestamps,
  absolute paths, or build‑host specifics into artifacts. There is a dedicated
  reproducible‑build path (containerized, under `build_infrastructure/`); the
  several `Dockerfile`s in the tree are build/sample‑bring‑up helpers, not the
  product.

## Installer, BOMs, and downstream packagers

- This repo produces **two co‑equal deliverables**: the **SDK** — shipped as the
  self‑extracting **`.bin` installer** — which you need to *build* an enclave, and
  the untrusted **runtime** (`urts`, `libsgx-enclave-common`) — shipped as distro
  packages (DEB/RPM) — which you need to *run* one. Neither is a footnote: there's
  no enclave without the SDK and no execution without the runtime. The repo is
  named for the SDK, so the `.bin` is the natural lead artifact, but keep both in
  mind when a change affects what ships.
- Installer/package contents are **BOM‑driven**
  (`build_infrastructure/linux/installer/**/BOMs/*.txt`). The BOMs are the source of
  truth for what ships: **if a file isn't in a BOM, it isn't released.** Read them
  to see both the high‑level package dependencies and the exact file set. When you
  add or rename a shipped file, update the relevant BOM.
- This source tree is also consumed by **downstream distribution packagers**, so
  keep it friendly to their constraints:
  - The **build phase should not require network downloads** — support building
    against already‑present dependencies (don't bake fetches into compile steps).
  - **Packaging should be skippable** — building the libraries/tools must not force
    the project's own packaging, so a packager can plug in their own.
- Dependency management is currently **manual** (submodules, in‑tree patches,
  download scripts); a package manager such as Conan is a reasonable future option.
- When defining packages, aim for Intel packages to **co‑exist** with community
  ones via a provides‑style relationship (e.g. an `intel-*` package that *provides*
  the community library name) rather than conflicting with them.
- On a **substantial** change, consider adding a manual changelog entry in **both**
  packaging trees — the RPM `%changelog` in
  `build_infrastructure/linux/installer/rpm/<pkg>/*.spec` and the Debian changelog
  in `build_infrastructure/linux/installer/deb/<pkg>/.../debian/changelog`. These
  are hand‑maintained and low‑fidelity: most changes are **not** enumerated there
  (the release notes carry the detail), so treat this as an optional nudge for
  significant changes only.
