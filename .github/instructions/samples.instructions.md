---
description: "Suggestions for the sample enclaves and host apps under SampleCode in the Intel SGX SDK."
applyTo: "SampleCode/**/*.{c,cc,cpp,cxx,h,hpp,edl}"
---
# Sample code guidance

These are **suggestions** for review and authoring under `SampleCode/`. Use
judgment; match the surrounding sample's structure.

## Samples are teaching code

People copy samples into their own projects, so model the **right** patterns:

- Show correct boundary usage — proper EDL annotations (`[in]`/`[out]`, `[size=...]`,
  `[string]`) and checked return codes (`sgx_status_t`).
- Favor clarity over cleverness; a sample should be easy to read end‑to‑end.
- Keep each sample **self‑contained** with minimal external dependencies.
- Build in both hardware and simulation mode (`SGX_MODE=SIM`) where the sample
  supports it.

## Conventions

- Keep the usual layout (host `App/`, enclave `Enclave/`, and the `.edl`).
- Samples ship **with** the SDK, so each must build **standalone** against the
  installed ("dist") layout — after `source <sdk>/environment`, using the installed
  headers and libraries. A sample may *also* build in the source‑tree layout when
  that's achievable without heavy makefile machinery, but standalone is the
  requirement; don't let an in‑tree convenience break the installed‑layout build.
- Don't embed real secrets or signing keys; use clearly‑marked placeholders.
- Match the sample's existing style (license/copyright header conventions are
  covered by the repository‑wide guidance).
