---
description: Comprehensive C++ code review for memory safety, undefined behavior, concurrency, and modern C++ idioms. Invokes the cpp-reviewer agent.
---

# C++ Code Review

This command invokes the **cpp-reviewer** agent for comprehensive C++-specific code review.

## What This Command Does

1. **Identify C++ Changes**: Find modified `.cpp`/`.h`/`.hpp` files via `git diff`
2. **Run Static Analysis**: Execute `clang-tidy` and `cppcheck`
3. **Security & Memory-Safety Scan**: Check for buffer overflows, use-after-free, format string bugs
4. **Concurrency Review**: Analyze thread safety, mutex usage, data races
5. **Modern C++ Idiom Check**: Verify C++17/20 best practices and RAII patterns
6. **Generate Report**: Categorize issues by severity

## When to Use

Use `/cpp-review` when:
- After writing or modifying C++ code
- Before committing C++ changes
- Reviewing pull requests with C++ code
- Onboarding to a new C++ codebase
- Learning modern C++ idioms

## Review Categories

### CRITICAL (Must Fix)
- Buffer overflows / out-of-bounds access
- Use-after-free / dangling pointers
- Format string vulnerabilities
- Integer overflow/underflow in arithmetic
- Command injection via `system()` / `popen()`
- Hardcoded credentials
- Raw `new`/`delete` without RAII ownership

### HIGH (Should Fix)
- Undefined behavior (signed overflow, strict aliasing)
- Data races on shared state without synchronization
- Missing `lock_guard`/`unique_lock` RAII
- Deadlocks from inconsistent lock ordering
- Functions > 60 lines / nesting > 4 levels

### MEDIUM (Consider)
- Raw arrays instead of `std::array`/`std::span`
- Missing `[[nodiscard]]` on error-returning functions
- `const` correctness violations
- Missed move semantics / unnecessary copies
- Missing `reserve()` before `push_back` loops

## Automated Checks Run

```bash
# Static analysis
clang-tidy **/*.cpp -- -std=c++17

# Additional checks
cppcheck --enable=all --std=c++17 src/

# Sanitizers (if building from source)
clang++ -fsanitize=address,undefined -std=c++17 -Wall -Wextra ...

# Memory analysis
valgrind --leak-check=full ./binary
```

## Example Usage

```text
User: /cpp-review

Agent:
# C++ Code Review Report

## Files Reviewed
- src/service/session.cpp (modified)
- include/service/session.h (modified)

## Static Analysis Results
✓ clang-tidy: 1 warning
⚠ cppcheck: 1 issue

## Issues Found

[CRITICAL] Use-After-Free
File: src/service/session.cpp:45
Issue: Raw pointer used after delete
```cpp
Session* s = new Session();
delete s;
s->refresh();  // use-after-free
```
Fix: Use std::unique_ptr
```cpp
auto s = std::make_unique<Session>();
s->refresh();  // safe: s owns the resource
```

[HIGH] Data Race
File: src/service/session.cpp:72
Issue: Shared map accessed without synchronization
```cpp
std::map<std::string, Session*> cache;  // no lock!

Session* GetSession(const std::string& id) {
    return cache[id];  // data race
}
```
Fix: Protect with std::shared_mutex
```cpp
std::map<std::string, Session*> cache;
std::shared_mutex cache_mu;

Session* GetSession(const std::string& id) {
    std::shared_lock lock(cache_mu);
    auto it = cache.find(id);
    return it != cache.end() ? it->second : nullptr;
}
```

## Summary
- CRITICAL: 1
- HIGH: 1
- MEDIUM: 0

Recommendation: Block merge until CRITICAL issue is fixed
```

## Approval Criteria

| Status | Condition |
|--------|-----------|
| Approve | No CRITICAL or HIGH issues |
| Warning | Only MEDIUM issues (merge with caution) |
| Block | CRITICAL or HIGH issues found |

## Integration with Other Commands

- Use `/cpp-test` first to ensure tests pass
- Use `/cpp-build` if build errors occur
- Use `/cpp-review` before committing
- Use `/code-review` for non-C++ specific concerns

## Related

- Agent: `agents/cpp-reviewer.md`
- Related: `/cpp-test`, `/cpp-build`
