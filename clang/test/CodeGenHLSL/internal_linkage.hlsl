// RUN: %clang_cc1 -finclude-default-header -x hlsl -triple \
// RUN:   dxil-pc-shadermodel6.3-library %s \
// RUN:   -emit-llvm -disable-llvm-passes -o - | FileCheck %s

// unused internal function - should not be included in final code
// CHECK-NOT: define void @"?f1@@YAXXZ"()
void f1() {
}

// used internal function - should be included in final code and marked internal
// CHECK-DAG: define internal void @"?f2@@YAXXZ"()
void f2() {
}

// exported function calling an internal one
// CHECK-DAG: define void @"?f3@@YAXXZ"()
export void f3() {
    f2();
}
