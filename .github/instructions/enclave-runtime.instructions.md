---
description: "Suggestions for the untrusted host-side enclave runtime (urts, enclave_common) in the Intel SGX SDK."
applyTo: "enclave_runtime/**/*.{c,cc,cpp,cxx,h,hpp,edl}"
---
# Enclave runtime guidance

These are **suggestions** for review and authoring under `enclave_runtime/`
(`urts` and `enclave_common`). Use judgment; match the surrounding code.

## What this code is

This is **untrusted, host‑side** code: it loads, initializes, and manages the
lifecycle of enclaves, and dispatches `ECALL`/`OCALL` transitions. It provides **no**
security property to the enclave — never assume host integrity on the enclave's
behalf, and don't treat enclave outputs as trusted without the enclave's own
attestation/sealing guarantees.

It consumes `common/` headers: use the **public** API (`common/inc/`, e.g.
`sgx_urts.h`) and treat `common/inc/internal/` as internal.

In the dependency graph this code (plus parts of `common/`) is the **leaf**: the
SDK loosely builds on top of it, not the other way around. Keep it self‑contained
and avoid reaching back into SDK internals. Defer to this component's `README.md`
for authoritative detail.

## Robustness

- Check return codes on the create / initialize / `ECALL` / destroy paths and handle
  failures explicitly; don't ignore an `sgx_status_t`.
- Free and destroy enclaves on **all** paths (including error paths); don't leak
  enclave IDs, handles, or mapped memory.
- Handle enclave‑loss / power‑transition conditions where the runtime is expected to
  reload or surface the error.
- Be careful parsing enclave files and metadata — validate sizes and offsets before
  trusting them.

## General hygiene

- Initialize variables; prefer fixed‑width integer types.
- Match existing formatting rather than reformatting (license/copyright header
  conventions are covered by the repository‑wide guidance).

