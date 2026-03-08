---
paths:
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.hpp"
  - "**/*.hxx"
---
# C++ Patterns

> This file extends [common/patterns.md](../common/patterns.md) with C++ specific content.

## RAII for Resource Management

Bind resource lifetime to object lifetime -- the foundational C++ pattern:

```cpp
class FileHandle {
public:
    explicit FileHandle(const std::string& path)
        : handle_(std::fopen(path.c_str(), "r")) {
        if (!handle_) throw std::runtime_error("Failed to open: " + path);
    }
    ~FileHandle() { if (handle_) std::fclose(handle_); }

    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    FileHandle(FileHandle&& other) noexcept
        : handle_(std::exchange(other.handle_, nullptr)) {}
    FileHandle& operator=(FileHandle&& other) noexcept {
        if (this != &other) {
            if (handle_) std::fclose(handle_);
            handle_ = std::exchange(other.handle_, nullptr);
        }
        return *this;
    }

private:
    std::FILE* handle_;
};
```

## Polymorphism Without vtable Overhead

Use `std::variant` or type erasure when runtime dispatch is needed without inheritance:

```cpp
using Shape = std::variant<Circle, Rectangle, Triangle>;

double area(const Shape& shape) {
    return std::visit([](const auto& s) { return s.area(); }, shape);
}
```

## Error Handling

Prefer `std::expected` (C++23, requires `-std=c++23`) or Result-type patterns over exceptions for recoverable errors:

```cpp
// C++23 std::expected
std::expected<Config, ParseError> parse_config(std::string_view input);

// Pre-C++23: custom Result type
template<typename T, typename E>
class Result {
    std::variant<T, E> value_;
public:
    bool has_value() const { return std::holds_alternative<T>(value_); }
    const T& value() const { return std::get<T>(value_); }
    const E& error() const { return std::get<E>(value_); }
};
```

## Reference

See skill: `cpp-coding-standards` for comprehensive C++ Core Guidelines patterns including concurrency, templates, and class design.
