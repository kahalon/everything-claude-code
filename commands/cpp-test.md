---
description: TDD for C++. Write parameterized tests with Google Test or Catch2 first, then implement. Verify 80%+ coverage with gcov/lcov or llvm-cov.
---

# C++ TDD Command

This command enforces test-driven development methodology for C++ code using Google Test or Catch2.

## What This Command Does

1. **Define Types/Interfaces**: Scaffold function signatures first
2. **Write Parameterized Tests**: Create comprehensive test cases (RED)
3. **Run Tests**: Verify tests fail for the right reason
4. **Implement Code**: Write minimal code to pass (GREEN)
5. **Refactor**: Improve while keeping tests green
6. **Check Coverage**: Ensure 80%+ coverage with gcov/lcov or llvm-cov

## When to Use

Use `/cpp-test` when:
- Implementing new C++ functions
- Adding test coverage to existing code
- Fixing bugs (write failing test first)
- Building critical business logic
- Learning TDD workflow in C++

## TDD Cycle

```
RED     → Write failing parameterized test
GREEN   → Implement minimal code to pass
REFACTOR → Improve code, tests stay green
REPEAT  → Next test case
```

## Example Session

````
User: /cpp-test I need a function to validate email addresses

Agent:
# TDD Session: Email Validator

## Step 1: Define Interface

```cpp
// include/validator/email.h
#pragma once
#include <string>
#include <stdexcept>

namespace validator {

// ValidateEmail checks if the given string is a valid email address.
// Throws std::invalid_argument if invalid, returns normally if valid.
void ValidateEmail(const std::string& email);

}  // namespace validator
```

## Step 2: Write Parameterized Tests (RED) — Google Test

```cpp
// tests/validator/email_test.cpp
#include "validator/email.h"
#include <gtest/gtest.h>

namespace validator {

struct EmailTestCase {
    std::string name;
    std::string email;
    bool should_throw;
};

class EmailValidatorTest : public ::testing::TestWithParam<EmailTestCase> {};

TEST_P(EmailValidatorTest, ValidatesCorrectly) {
    const auto& tc = GetParam();
    if (tc.should_throw) {
        EXPECT_THROW(ValidateEmail(tc.email), std::invalid_argument) << tc.name;
    } else {
        EXPECT_NO_THROW(ValidateEmail(tc.email)) << tc.name;
    }
}

INSTANTIATE_TEST_SUITE_P(
    EmailCases, EmailValidatorTest,
    ::testing::Values(
        // Valid emails
        EmailTestCase{"simple email",    "user@example.com",      false},
        EmailTestCase{"with subdomain",  "user@mail.example.com", false},
        EmailTestCase{"with plus",       "user+tag@example.com",  false},
        EmailTestCase{"with dots",       "first.last@example.com",false},
        // Invalid emails
        EmailTestCase{"empty string",    "",                      true},
        EmailTestCase{"no at sign",      "userexample.com",       true},
        EmailTestCase{"no domain",       "user@",                 true},
        EmailTestCase{"no local part",   "@example.com",          true},
        EmailTestCase{"double at",       "user@@example.com",     true},
        EmailTestCase{"spaces",          "user @example.com",     true}
    )
);

}  // namespace validator
```

## Catch2 Alternative

```cpp
#include "validator/email.h"
#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>

TEST_CASE("ValidateEmail", "[validator]") {
    SECTION("valid emails pass") {
        auto email = GENERATE("user@example.com",
                              "user+tag@example.com",
                              "first.last@example.com");
        REQUIRE_NOTHROW(validator::ValidateEmail(email));
    }
    SECTION("invalid emails throw") {
        auto email = GENERATE("", "userexample.com", "user@", "@example.com");
        REQUIRE_THROWS_AS(validator::ValidateEmail(email), std::invalid_argument);
    }
}
```

## Step 3: Run Tests - Verify FAIL

```bash
$ cmake --build build/ && ctest --test-dir build/

[ RUN      ] EmailValidatorTest/EmailCases.ValidatesCorrectly/0
[  FAILED  ] EmailValidatorTest/EmailCases.ValidatesCorrectly/0 (0 ms)
```

Tests fail as expected (function not implemented).

## Step 4: Implement Minimal Code (GREEN)

```cpp
// src/validator/email.cpp
#include "validator/email.h"
#include <regex>
#include <stdexcept>

namespace validator {

void ValidateEmail(const std::string& email) {
    if (email.empty()) {
        throw std::invalid_argument("email cannot be empty");
    }
    static const std::regex kEmailRegex(
        R"([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})");
    if (!std::regex_match(email, kEmailRegex)) {
        throw std::invalid_argument("email format is invalid");
    }
}

}  // namespace validator
```

## Step 5: Run Tests - Verify PASS

```bash
$ cmake --build build/ && ctest --test-dir build/

[==========] 10 tests from 1 test suite ran.
[  PASSED  ] 10 tests.
```

All tests passing!

## Step 6: Check Coverage

```bash
# gcov / lcov
cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="--coverage" ..
cmake --build . && ctest
lcov --capture --directory . --output-file coverage.info
genhtml coverage.info --output-directory html/
# Open html/index.html

# llvm-cov
cmake -DCMAKE_CXX_FLAGS="-fprofile-instr-generate -fcoverage-mapping" ..
cmake --build . && LLVM_PROFILE_FILE="cov.profraw" ctest
llvm-profdata merge -sparse cov.profraw -o coverage.profdata
llvm-cov report ./tests/email_test -instr-profile=coverage.profdata
```

Coverage: 100%

## TDD Complete!
````

## Test Patterns

### Google Test Parameterized
```cpp
INSTANTIATE_TEST_SUITE_P(
    SuiteName, FixtureName,
    ::testing::Values(/* cases */)
);
```

### Google Test Fixture
```cpp
class MyFixture : public ::testing::Test {
protected:
    void SetUp() override { /* init */ }
    void TearDown() override { /* cleanup */ }
    MyObject obj_;
};

TEST_F(MyFixture, BehaviorUnderCondition) {
    ASSERT_TRUE(obj_.IsValid());
    EXPECT_EQ(obj_.Compute(), 42);
}
```

### Catch2 Sections
```cpp
TEST_CASE("MyClass", "[myclass]") {
    MyClass obj;
    SECTION("default state is valid") {
        REQUIRE(obj.IsValid());
    }
    SECTION("compute returns expected value") {
        REQUIRE(obj.Compute() == 42);
    }
}
```

## Coverage Commands

```bash
# gcov / lcov
cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="--coverage" ..
cmake --build . && ctest
lcov --capture --directory . --output-file coverage.info
genhtml coverage.info --output-directory html/

# llvm-cov
cmake -DCMAKE_CXX_FLAGS="-fprofile-instr-generate -fcoverage-mapping" ..
llvm-profdata merge -sparse *.profraw -o coverage.profdata
llvm-cov report ./binary -instr-profile=coverage.profdata
```

## Coverage Targets

| Code Type | Target |
|-----------|--------|
| Critical business logic | 100% |
| Public APIs | 90%+ |
| General code | 80%+ |
| Generated code | Exclude |

## TDD Best Practices

**DO:**
- Write test FIRST, before any implementation
- Run tests after each change
- Use `TEST_P`/`GENERATE` for parameterized coverage
- Test behavior, not implementation details
- Include edge cases (empty, null, max values)
- Use `ASSERT_*` for fatal failures, `EXPECT_*` for non-fatal

**DON'T:**
- Write implementation before tests
- Skip the RED phase
- Call `abort()` as a test-fail mechanism — use `ASSERT_*`
- Use `sleep()` in tests
- Ignore flaky tests

## Related Commands

- `/cpp-build` - Fix build errors
- `/cpp-review` - Review code after implementation
- `/verify` - Run full verification loop

## Related

- Skill: `skills/tdd-workflow/`
