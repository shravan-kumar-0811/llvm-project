// RUN: %clang_cc1 -fsyntax-only -verify=scalar,neon -std=c++11 \
// RUN:   -triple aarch64 -target-cpu cortex-a75 \
// RUN:   -target-feature +fp8 -Wno-unused %s

// REQUIRES: aarch64-registered-target

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

