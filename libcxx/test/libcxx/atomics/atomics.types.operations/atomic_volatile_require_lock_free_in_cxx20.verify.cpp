//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// <atomic>

// UNSUPPORTED: c++03, c++11, c++17

#include <atomic>

struct arr {
  int x[32];
  int y;

  void method() {}
};

void f() {
  std::memory_order ord = std::memory_order_relaxed;

  int expected = 0, desired = 0;
  std::atomic<int> i{};
  i.operator=(0);
  i.store(0, ord);
  i.load(ord);
  i.operator int();
  i.exchange(0, ord);
  i.compare_exchange_weak(expected, desired, ord);
  i.compare_exchange_weak(expected, desired, ord, ord);
  i.compare_exchange_strong(expected, desired, ord);
  i.compare_exchange_strong(expected, desired, ord, ord);

  volatile std::atomic<int> vi{};
  vi.operator=(0);
  vi.store(0, ord);
  vi.load(ord);
  vi.operator int();
  vi.exchange(0, ord);
  vi.compare_exchange_weak(expected, desired, ord);
  vi.compare_exchange_weak(expected, desired, ord, ord);
  vi.compare_exchange_strong(expected, desired, ord);
  vi.compare_exchange_strong(expected, desired, ord, ord);

  arr test_value;

  volatile std::atomic<arr> va{};
  // expected-error@+1 {{call to deleted member function 'operator='}}
  va.operator=(test_value); 
  
  // expected-error@+1 {{no matching member function for call to 'store'}}
  va.store(test_value, ord);
  
  // expected-error@+1 {{no matching member function for call to 'load'}}
  va.load(ord);
  
  // expected-error@+1 {{no matching member function for call to 'operator arr'}}
  va.operator arr();

  // expected-error@+1 {{no matching member function for call to 'exchange'}}
  va.exchange(test_value, ord);

  // expected-error@+1 {{no matching member function for call to 'compare_exchange_weak'}}
  va.compare_exchange_weak(test_value, test_value, ord);

  // expected-error@+1 {{no matching member function for call to 'compare_exchange_weak'}}
  va.compare_exchange_weak(test_value, test_value, ord, ord);

  // expected-error@+1 {{no matching member function for call to 'compare_exchange_strong'}}
  va.compare_exchange_strong(test_value, test_value, ord);
  
  // expected-error@+1 {{no matching member function for call to 'compare_exchange_strong'}}
  va.compare_exchange_strong(test_value, test_value, ord, ord);

  void (arr::*fptr)();

  std::atomic<void (arr::*)()> vfp;
  vfp.store(&test_value.method);

}
