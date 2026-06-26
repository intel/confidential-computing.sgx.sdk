---
description: "Optional pattern for adding a NEW external C interface (public header) in common/inc: a canonical C ABI plus an opt-in, header-only C++ view."
applyTo: "common/inc/*.h"
---
# Public header (external C interface) guidance

This applies **only** when you're adding a new external C interface — a public
header under `common/inc/`, or a brand‑new struct/API definition dropped into an
existing header (one with no consumers yet). It's a pattern the SDK has found works
well for headers that are consumed broadly (from C, C++, and other languages via
FFI); it is **a suggestion, not a requirement**, and existing headers that don't
follow it are fine. For everyday edits to existing headers, the
stability/compatibility points in the SDK guidance are what matter.

First, consider whether the new definitions can stand alone in their own dedicated
public header; if so, prefer that over polluting an existing header with unrelated
additions. Even when something fits logically into an existing header, weigh whether
modern consumers actually need the older definitions that header pulls in — if not,
keep the new surface lean so callers don't consume what they don't need.

When the header exposes a new structured interface, consider a two‑layer shape: a
canonical C ABI, plus an optional in‑header C++ view. The flow is internal C++17 →
flatten to a portable C ABI → opt‑in, header‑only layer that restores an
object‑oriented view → consumers use it as modern C++ (or from another language).
Prefer consuming an interface the way an external customer would, rather than
reaching into private internals.

- **Layer 0 — canonical C** inside `extern "C"`: ABI‑stable, vanilla‑C / FFI
  consumable. Keep fields fixed‑width (label valid values with `#define`s rather
  than narrowing the type). If versioned, put a version field at **offset 0** for
  dispatch; consider `static_assert`s on the offsets.
- **Guard each typedef** with its own `#ifndef __foo_t` — a boundary‑crossing type
  may also be emitted by the edger8r‑generated `*_t.h` / `*_u.h`.
- **Layer 1 — C++ helpers** behind `#ifdef __cplusplus`: header‑only, opt‑in,
  **non‑owning / view‑only**, minimal STL, no exceptions/RTTI. It must **never**
  alter the C ABI and is never compiled for vanilla C.
- **Degrade across standards** — a consumer may compile these headers at a newer
  standard than the SDK builds at, so feature‑gate (e.g. `std::span` only when
  `__cplusplus >= 202002L`, `std::string_view` only when `>= 201703L`).

## Optional example (illustrative only, not real SDK code or officially endorsed pattern - deviations are perfectly fine)

*This is a direction sketch, not real SDK code and not an endorsed, drop‑in
pattern — it exists to visualize the two‑layer shape, nothing more.*

Two‑layer header (invented `sgx_binary_blob_v1_t`) — a canonical C ABI struct plus an
opt‑in, non‑owning C++ view. It carries an opaque payload that is *either* raw bytes
*or* text, tagged by `kind`; the view exposes a `bytes()` and a `text()` accessor that
return the same type on every standard, via thin `se_span` / `se_string_view` aliases.
Note the per‑typedef guard, the version at offset 0, and the opt‑out macro; the C++
layer changes nothing about the C ABI:

```c
/* The opt-in C++ view below is on by default; define SGX_API_NO_CXX_ADAPTERS
   before including this header to drop it and compile as pure C. */

#ifdef __cplusplus
extern "C" {
#endif

#define SGX_BLOB_KIND_BYTES 0x00u   /* opaque raw bytes              */
#define SGX_BLOB_KIND_TEXT  0x01u   /* UTF-8 text, NUL-terminated    */

#ifndef __sgx_binary_blob_v1_t          /* edger8r *_t.h/_u.h may also define it */
#define __sgx_binary_blob_v1_t
/** A versioned, self-describing binary blob: a small fixed header followed by
 *  `content_len` bytes of inline payload. Dispatch on `version` (offset 0); the
 *  payload is raw bytes or text per `kind`. */
typedef struct _sgx_binary_blob_v1_t {
    uint32_t version;       /* 0  — this structure's layout version          */
    uint32_t kind;          /* 4  — SGX_BLOB_KIND_* (stays uint32_t for ABI) */
    uint32_t content_len;   /* 8  — payload bytes: raw size, or text length   */
                            /*      including the terminating NUL            */
    uint8_t  content[];     /* 12 — `content_len` bytes of inline payload     */
} sgx_binary_blob_v1_t;
#endif /* __sgx_binary_blob_v1_t */

#ifdef __cplusplus
}   /* extern "C" */

#if !defined(SGX_API_NO_CXX_ADAPTERS)
/* Uniform view API across standards: alias to the std types where available,
   else a minimal inline stand-in with the same shape. */
#if __cplusplus >= 202002L
#  include <span>
template <class T> using se_span = std::span<T>;
#else
template <class T> struct se_span { T* p; size_t n;
    T* data() const { return p; } size_t size() const { return n; } };
#endif
#if __cplusplus >= 201703L
#  include <string_view>
using se_string_view = std::string_view;
#else
struct se_string_view { const char* p; size_t n;
    const char* data() const { return p; } size_t size() const { return n; } };
#endif

enum class sgx_blob_kind : uint32_t {   /* mirror the C value labels */
    bytes = SGX_BLOB_KIND_BYTES,
    text  = SGX_BLOB_KIND_TEXT,
};

/* Opt-in, header-only, non-owning view: copies nothing, never alters the C ABI. */
class sgx_binary_blob_v1_view {
public:
    explicit sgx_binary_blob_v1_view(const sgx_binary_blob_v1_t& b) : b_(b) {}

    uint32_t      version() const { return b_.version; }
    sgx_blob_kind kind()    const { return static_cast<sgx_blob_kind>(b_.kind); }

    /* Raw payload; empty unless this blob holds bytes. */
    se_span<const uint8_t> bytes() const {
        return kind() == sgx_blob_kind::bytes
            ? se_span<const uint8_t>{ b_.content, b_.content_len } : se_span<const uint8_t>{};
    }
    /* Text payload, NUL excluded; empty unless this blob holds text. */
    se_string_view text() const {
        return (kind() == sgx_blob_kind::text && b_.content_len)
            ? se_string_view{ reinterpret_cast<const char*>(b_.content), b_.content_len - 1u }
            : se_string_view{};
    }

private:
    const sgx_binary_blob_v1_t& b_;   /* view-only: copies nothing */
};
#endif /* !SGX_API_NO_CXX_ADAPTERS */
#endif /* __cplusplus */
```
