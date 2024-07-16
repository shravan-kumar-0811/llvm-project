// RUN: %clang_cc1 -fsyntax-only -verify -triple aarch64 -target-feature +fp8 %s

__fpm8 test_static_cast_from_char(char in) {
  return static_cast<__fpm8>(in); // expected-error {{static_cast from 'char' to '__fpm8' is not allowed}}
}

char test_static_cast_to_char(__fpm8 in) {
  return static_cast<char>(in); // expected-error {{static_cast from '__fpm8' to 'char' is not allowed}}
}
