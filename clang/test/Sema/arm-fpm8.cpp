// RUN: %clang_cc1 -fsyntax-only -verify=scalar,neon -triple aarch64-arm-none-eabi \
// RUN: -target-feature -fp8 -target-feature +neon %s

// REQUIRES: aarch64-registered-target
__fpm8 test_static_cast_from_char(char in) {
  return static_cast<__fpm8>(in); // scalar-error {{static_cast from 'char' to '__fpm8' is not allowed}}
}

char test_static_cast_to_char(__fpm8 in) {
  return static_cast<char>(in); // scalar-error {{static_cast from '__fpm8' to 'char' is not allowed}}
}
void test(bool b) {
  __fpm8 fpm8;

  fpm8 + fpm8;  // scalar-error {{invalid operands to binary expression ('__fpm8' and '__fpm8')}}
  fpm8 - fpm8;  // scalar-error {{invalid operands to binary expression ('__fpm8' and '__fpm8')}}
  fpm8 * fpm8;  // scalar-error {{invalid operands to binary expression ('__fpm8' and '__fpm8')}}
  fpm8 / fpm8;  // scalar-error {{invalid operands to binary expression ('__fpm8' and '__fpm8')}}
  ++fpm8;       // scalar-error {{cannot increment value of type '__fpm8'}}
  --fpm8;       // scalar-error {{cannot decrement value of type '__fpm8'}}

  char u8;

  fpm8 + u8;   // scalar-error {{invalid operands to binary expression ('__fpm8' and 'char')}}
  u8 + fpm8;   // scalar-error {{invalid operands to binary expression ('char' and '__fpm8')}}
  fpm8 - u8;   // scalar-error {{invalid operands to binary expression ('__fpm8' and 'char')}}
  u8 - fpm8;   // scalar-error {{invalid operands to binary expression ('char' and '__fpm8')}}
  fpm8 * u8;   // scalar-error {{invalid operands to binary expression ('__fpm8' and 'char')}}
  u8 * fpm8;   // scalar-error {{invalid operands to binary expression ('char' and '__fpm8')}}
  fpm8 / u8;   // scalar-error {{invalid operands to binary expression ('__fpm8' and 'char')}}
  u8 / fpm8;   // scalar-error {{invalid operands to binary expression ('char' and '__fpm8')}}
  fpm8 = u8;   // scalar-error {{assigning to '__fpm8' from incompatible type 'char'}}
  u8 = fpm8;   // scalar-error {{assigning to 'char' from incompatible type '__fpm8'}}
  fpm8 + (b ? u8 : fpm8);  // scalar-error {{incompatible operand types ('char' and '__fpm8')}}
}

#include <arm_neon.h>

void test_vector(fpm8x8_t a, fpm8x8_t b, uint8x8_t c) {
  a + b;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'fpm8x8_t')}}
  a - b;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'fpm8x8_t')}}
  a * b;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'fpm8x8_t')}}
  a / b;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'fpm8x8_t')}}

  a + c;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'uint8x8_t' (vector of 8 'uint8_t' values))}}
  a - c;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'uint8x8_t' (vector of 8 'uint8_t' values))}}
  a * c;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'uint8x8_t' (vector of 8 'uint8_t' values))}}
  a / c;  // neon-error {{invalid operands to binary expression ('fpm8x8_t' (vector of 8 'fpm8_t' values) and 'uint8x8_t' (vector of 8 'uint8_t' values))}}
  c + b;  // neon-error {{invalid operands to binary expression ('uint8x8_t' (vector of 8 'uint8_t' values) and 'fpm8x8_t' (vector of 8 'fpm8_t' values))}}
  c - b;  // neon-error {{invalid operands to binary expression ('uint8x8_t' (vector of 8 'uint8_t' values) and 'fpm8x8_t' (vector of 8 'fpm8_t' values))}}
  c * b;  // neon-error {{invalid operands to binary expression ('uint8x8_t' (vector of 8 'uint8_t' values) and 'fpm8x8_t' (vector of 8 'fpm8_t' values))}}
  c / b;  // neon-error {{invalid operands to binary expression ('uint8x8_t' (vector of 8 'uint8_t' values) and 'fpm8x8_t' (vector of 8 'fpm8_t' values))}}
}
