---
paths:
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.hpp"
  - "**/*.hxx"
---
# C++ Hooks

> This file extends [common/hooks.md](../common/hooks.md) with C++ specific content.

## PostToolUse Hooks

Configure in `~/.claude/settings.json`:

- **clang-format**: Auto-format `.cpp`/`.h` files after edit
- **clang-tidy**: Run static analysis checks after editing C++ files

## Warnings

- Warn about `std::cout` / `printf` debug output left in edited files (use structured logging instead)

## Build Verification

- Run **CMake** or **Bazel** build check after edits to catch compilation errors early
- Use `cmake --build <build-dir> --target <changed_target>` for incremental verification

## Reference

See agent: `cpp-build-resolver` for automated build and clang-tidy error resolution.
