// RUN: %clang_cc1 -fsyntax-only -verify -triple aarch64 -target-feature +fp8 %s

__fpm8 test_cast_from_float(unsigned in) {
  return (__fpm8)in; // expected-error {{cannot cast 'unsigned int' to '__fpm8'; types are not compatible}}
}

unsigned test_cast_to_int(__fpm8 in) {
  return (unsigned)in; // expected-error {{cannot cast '__fpm8' to 'unsigned int'; types are not compatible}}
}
