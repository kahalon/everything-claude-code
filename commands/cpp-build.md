---
description: Fix C++ build errors, clang-tidy warnings, and linker issues incrementally. Invokes the cpp-build-resolver agent for minimal, surgical fixes.
---

# C++ Build and Fix

This command invokes the **cpp-build-resolver** agent to incrementally fix C++ build errors with minimal changes.

## What This Command Does

1. **Run Diagnostics**: Execute `cmake --build`, `clang-tidy`, `cppcheck`
2. **Parse Errors**: Group by file and sort by severity
3. **Fix Incrementally**: One error at a time
4. **Verify Each Fix**: Re-run build after each change
5. **Report Summary**: Show what was fixed and what remains

## When to Use

Use `/cpp-build` when:
- `cmake --build` fails with errors
- `clang-tidy` reports issues
- `cppcheck` shows warnings
- Linker errors appear after adding/removing files
- After pulling changes that break the build

## Diagnostic Commands Run

```bash
# Primary build check
cmake --build build/ 2>&1          # or: make / ninja / bazel build //...

# Static analysis
clang-tidy src/**/*.cpp --

# Additional checks
cppcheck --enable=all src/

# Full build with verbose output
cmake --build build/ -- -j$(nproc) 2>&1 | head -50
```

## Example Session

```text
User: /cpp-build

Agent:
# C++ Build Resolution

## Initial Diagnostics

```bash
$ cmake --build build/ 2>&1
src/service/user.cpp:25:5: error: use of undeclared identifier 'UserRepository'
src/handler/api.cpp:42:12: error: no viable conversion from 'std::string' to 'int'
src/handler/api.cpp:58:1: error: non-void function does not return a value
```

Errors found: 3

## Fix 1: Undeclared Identifier

File: src/service/user.cpp:25
Error: use of undeclared identifier 'UserRepository'
Cause: Missing #include

```cpp
// Added include
#include "repository/user_repository.h"

// Changed
UserRepository repo;
// To (using fully qualified name from header)
repository::UserRepository repo;
```

```bash
$ cmake --build build/ 2>&1
# 2 errors remaining
```

## Fix 2: Type Mismatch

File: src/handler/api.cpp:42
Error: no viable conversion from 'std::string' to 'int'

```cpp
// Changed
int count = params.Get("count");
// To
int count = std::stoi(params.Get("count"));
```

```bash
$ cmake --build build/ 2>&1
# 1 error remaining
```

## Fix 3: Missing Return

File: src/handler/api.cpp:58
Error: non-void function does not return a value

```cpp
User* GetUser(const std::string& id) {
    if (id.empty()) {
        return nullptr;
    }
    // Added missing return
    return FindUser(id);
}
```

```bash
$ cmake --build build/ 2>&1
# Build successful!
```

## Final Verification

```bash
$ clang-tidy src/**/*.cpp --
# No issues

$ ctest --test-dir build/
[==========] All tests passed.
```

## Summary

| Metric | Count |
|--------|-------|
| Build errors fixed | 3 |
| clang-tidy warnings fixed | 0 |
| Files modified | 2 |
| Remaining issues | 0 |

Build Status: SUCCESS
```

## Common Errors Fixed

| Error | Typical Fix |
|-------|-------------|
| `undefined reference to X` | Add library to link target / check symbol visibility |
| `no member named X in Y` | Wrong type, missing header, or typo |
| `use of undeclared identifier` | Missing `#include` or namespace |
| `template instantiation depth exceeded` | Recursive template; add base case |
| `multiple definition of X` | Missing `#pragma once` or `inline` keyword |
| `undefined symbol` (linker) | Link order, missing `-l`, or `target_link_libraries` |
| `conflicting types` | Header mismatch; unify declarations |
| ABI mismatch | Consistent `-std=c++XX` across all translation units |

## Fix Strategy

1. **Compilation errors first** - Code must compile
2. **Linker errors second** - Fix missing symbols and libraries
3. **clang-tidy warnings third** - Style and best practices
4. **One fix at a time** - Verify each change
5. **Minimal changes** - Don't refactor, just fix

## Stop Conditions

The agent will stop and report if:
- Same error persists after 3 attempts
- Fix introduces more errors
- Requires architectural changes
- Missing external dependencies

## Related Commands

- `/cpp-test` - Run tests after build succeeds
- `/cpp-review` - Review code quality
- `/verify` - Full verification loop

## Related

- Agent: `agents/cpp-build-resolver.md`
