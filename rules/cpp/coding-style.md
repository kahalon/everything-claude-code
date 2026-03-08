---
paths:
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.hpp"
  - "**/*.hxx"
---
# C++ Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with C++ specific content.

## Standards

- Follow the [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- Target **C++17** minimum; prefer **C++20** features when available
- Use `auto`, structured bindings, `std::optional`, and `std::variant`

## Immutability

Prefer immutable data by default:

```cpp
// Con.1 + ES.25: const/constexpr by default
const int max_retries{3};
constexpr double pi = 3.14159265358979;

// Con.2: const member functions by default
class Sensor {
public:
    const std::string& id() const { return id_; }  // Con.2: const method
    double reading() const { return reading_; }
private:
    std::string id_;        // no const on data members (breaks move/copy)
    double reading_{0.0};
};
```

## Value Semantics & RAII

- Prefer value semantics over pointer semantics (C.10, F.20)
- Use RAII for all resource management (R.1, P.8)
- No raw `new`/`delete` -- use smart pointers (R.11, R.20)

## Formatting

- **clang-format** for code formatting
- **clang-tidy** for linting and static analysis

## Reference

See skill: `cpp-coding-standards` for comprehensive C++ Core Guidelines coverage.
