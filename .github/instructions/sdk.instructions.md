---
description: "Security-minded suggestions for the SDK libraries, tools, and shared headers (trusted + untrusted) in the Intel SGX SDK."
applyTo: "sdk/**/*.{c,cc,cpp,cxx,h,hpp,edl},common/**/*.{c,cc,cpp,cxx,h,hpp,edl}"
---
# SDK & common code guidance

These are **suggestions** for review and authoring under `sdk/` and `common/`. The
overriding goal is a safe trusted/untrusted boundary. Use judgment; match the
surrounding code.

## Know which side you're on

This scope spans **both** trust domains:

- **Trusted** — in‑enclave libraries (`trts`, `tlibc`, `tlibcxx`, `tlibcrypto`,
  `tservice`, `tseal`, `tprotected_fs`, `ttls`, …). Everything entering from the
  host — `ECALL` arguments, `OCALL` return values, and any host‑touchable memory —
  is **untrusted input**; validate it.
- **Untrusted** — host‑side helpers and tools (`utls`, `sign_tool`/`sgx_sign`,
  `edger8r`/`sgx_edger8r`, `encrypt_enclave`/`sgx_encrypt`). These provide no
  security property on the enclave's behalf.

`common/` is shared by the SDK **and** the enclave runtime. `common/inc/` is the
**public, stable** API surface — keep it backward‑compatible; treat
`common/inc/internal/` as internal. When a component under `sdk/` has its own
`README.md`, defer to it for authoritative detail (e.g. the SDK's use of `urts` for
simulation).

## External interfaces (headers shipped to consumers)

Headers that appear in the installer BOMs
(`build_infrastructure/linux/installer/**/BOMs/*.txt`) are **external interfaces**:

- Keep them **stable and C‑ABI compatible**. Don't break layout, sizes, or symbol
  signatures that existing callers depend on.
- **Document them well** — purpose and usage comments, not just include guards.
  These are read by people integrating the SDK.
- Favor **header splitting / piecewise consumption**. These headers are consumed
  broadly (including by DCAP and TDX components), so a newer consumer shouldn't have
  to pull in unrelated legacy definitions (e.g. an old quote format) just to use a
  current one.
- Internally you can and should use modern C++ (target **C++17**); expose a portable
  C ABI at the boundary.

### EDL‑included definitions

A struct that is included (directly or transitively) by an `.edl` file feeds the
`sgx_edger8r` glue‑code generator on **both** sides of the boundary. Beyond the
usual include guards, such a definition may need a **separate conditional
(`#ifdef`) section** so the header doesn't collide with the generated trusted /
untrusted counterpart code.

> Adding a **new external C interface** (a public header in `common/inc/`)? See the
> dedicated public‑headers guidance for the canonical‑C + opt‑in C++ view pattern.

## Crossing the boundary (EDL / edger8r)

- Prefer describing the boundary in `.edl` and letting `sgx_edger8r` generate the
  stubs rather than hand‑rolling transitions.
- Annotate pointers accurately: direction (`[in]`, `[out]`, `[in, out]`) and size
  (`[size=...]`, `[count=...]`, `[string]`). Wrong or missing sizes are a common
  source of boundary bugs.
- `[user_check]` skips the generated checks — the callee then owns all validation of
  that pointer.
- In trusted code, confirm buffers lie wholly inside (or wholly outside, as intended)
  the enclave before use, and re‑check values after an `OCALL` returns.

## Defensive trusted code

- Validate lengths and indices; avoid integer overflow in size math (check before
  multiplying/adding). Bound by the enclave allocation, not by host‑supplied lengths.
- Keep secret‑dependent timing/branching out of cryptographic paths; prefer the
  constant‑time primitives the SDK already provides.
- Clear secrets (keys, sealed plaintext) from memory when done.
- Stay freestanding — use the trusted libraries (`tlibc`/`tlibcxx`/`tlibcrypto`);
  don't assume a full host libc or syscalls.
- Check SDK return codes (`sgx_status_t` and friends) and fail closed.

## General hygiene

- Initialize variables; prefer fixed‑width integer types at the boundary.
- Match existing formatting rather than reformatting (license/copyright header
  conventions are covered by the repository‑wide guidance).

## Prefer modern C++ (within C++17)

The SDK's own code targets **C++17** — lean on it, but don't break the C ABI at the
boundary (the points above still win).

- **Mark deprecations.** When retiring a symbol, flag it so callers get a compile‑time
  warning rather than a silent change: use the SDK's portable `SGX_DEPRECATED` /
  `SGX_DEPRECATED_MSG("use X instead")` macros (from [sgx_defs.h](../../common/inc/sgx_defs.h))
  on shipped/C‑consumable declarations, or the standard `[[deprecated("…")]]`
  attribute in internal C++. For a whole header that's going away, an `#warning`
  line (as in `sgx_uae_launch.h`) is appropriate.
- **Use the preprocessor frugally.** Prefer real language constructs —
  `enum class`, `namespace`, `constexpr`, and `static_assert` — over `#define`d
  constants and function‑like macros. Reach for the preprocessor when you genuinely
  need it (C‑ABI/compat shims, include guards, platform/feature gates), not as a
  default.
- **Prefer C++ memory management and RAII.** Where a managed lifetime fits, prefer
  `std::make_unique` (and other RAII/smart‑pointer constructs) over raw `new`/`delete`
  or C `malloc`/`free`; a bare owning `new` is usually a smell. (`std::make_unique` is
  available in C++17; note the array‑overwrite forms are C++20 and off‑limits here.)
  This is a *where‑applicable* preference — C‑ABI surfaces, freestanding trusted code,
  and custom allocators may still need raw allocation; keep it deliberate.


