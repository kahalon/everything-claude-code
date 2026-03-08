---
paths:
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.hpp"
  - "**/*.hxx"
---
# C++ Testing

> This file extends [common/testing.md](../common/testing.md) with C++ specific content.

## Framework

Use **GoogleTest** / **GoogleMock** as the primary testing framework. **Catch2** is an acceptable alternative.

## Coverage

GCC + gcov/lcov:

```bash
cmake -S . -B build-cov -DENABLE_COVERAGE=ON
cmake --build build-cov -j
ctest --test-dir build-cov
lcov --capture --directory build-cov --output-file coverage.info
```

Clang + llvm-cov:

```bash
LLVM_PROFILE_FILE="build/default.profraw" ctest --test-dir build
llvm-profdata merge -sparse build/default.profraw -o build/default.profdata
llvm-cov report build/example_tests -instr-profile=build/default.profdata
```

## Test Organization

Use `TEST_F` for fixtures and `TEST_P` for parameterized tests:

```cpp
class UserStoreTest : public ::testing::Test {
protected:
    void SetUp() override {
        store = std::make_unique<UserStore>(":memory:");
    }
    std::unique_ptr<UserStore> store;
};

TEST_F(UserStoreTest, FindsExistingUser) {
    auto user = store->Find("alice");
    ASSERT_TRUE(user.has_value());
    EXPECT_EQ(user->name, "alice");
}
```

## Reference

See skill: `cpp-testing` for detailed GoogleTest patterns, CMake/CTest setup, and sanitizer configuration.
