//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// REQUIRES: has-unix-headers
// UNSUPPORTED: c++03, c++11
// UNSUPPORTED: libcpp-hardening-mode=none
// XFAIL: libcpp-hardening-mode=debug && availability-verbose_abort-missing
// REQUIRES: libcpp-has-abi-bounded-unique_ptr

// <memory>
//
// unique_ptr<T[]>
//
// T& operator[](std::size_t);

// This test ensures that we catch an out-of-bounds access in std::unique_ptr<T[]>::operator[]
// when unique_ptr has the appropriate ABI configuration.

#include <memory>

#include "check_assertion.h"

int main(int, char**) {
  {
    std::unique_ptr<int[]> ptr = std::make_unique<int[]>(5);
    TEST_LIBCPP_ASSERT_FAILURE(ptr[6] = 42, "unique_ptr<T[]>::operator[](index): index out of range");
  }

#if TEST_STD_VER >= 20
  {
    std::unique_ptr<int[]> ptr = std::make_unique_for_overwrite<int[]>(5);
    TEST_LIBCPP_ASSERT_FAILURE(ptr[6] = 42, "unique_ptr<T[]>::operator[](index): index out of range");
  }
#endif

  return 0;
}
