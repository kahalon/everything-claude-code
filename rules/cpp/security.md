---
paths:
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.hpp"
  - "**/*.hxx"
---
# C++ Security

> This file extends [common/security.md](../common/security.md) with C++ specific content.

## Memory Safety

- No raw `new`/`delete` -- use `std::unique_ptr` or `std::shared_ptr` (R.11, R.20)
- No `malloc()`/`free()` in C++ code (R.10)
- No `reinterpret_cast` without documented justification (ES.48)
- No C-style casts -- prefer `static_cast`; use `dynamic_cast` for RTTI; `const_cast` only for legacy API interop (ES.49, ES.50)

## Buffer Overflow Prevention

- Use `std::span` for non-owning array views with bounds information
- Use `std::string_view` instead of `const char*` for string references
- Prefer `std::array` and `std::vector` over C arrays (SL.con.1)
- Always bounds-check before indexing raw buffers

## Static Analysis & Sanitizers

- **clang-tidy**: run with `modernize-*`, `bugprone-*`, `cppcoreguidelines-*` checks
- **cppcheck**: supplementary static analysis
- **AddressSanitizer** (ASan): detect memory errors (use-after-free, buffer overflow)
- **UndefinedBehaviorSanitizer** (UBSan): detect undefined behavior
- **ThreadSanitizer** (TSan): detect data races

```bash
# Build with sanitizers
cmake -S . -B build -DENABLE_ASAN=ON -DENABLE_UBSAN=ON
cmake --build build -j
ctest --test-dir build --output-on-failure
```

## Reference

See agent: `cpp-reviewer` for automated security and memory safety review of C++ code.
