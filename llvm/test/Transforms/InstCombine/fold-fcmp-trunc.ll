; RUN: opt -passes=instcombine -S < %s | FileCheck %s


;CHECK-LABEL: @src(
;CHECK: %result = fcmp oge double %0, 1.000000e+02
;CHECK-NEXT: ret i1 %result
define i1 @src(double %0) {
    %trunc = fptrunc double %0 to float
    %result = fcmp oge float %trunc, 1.000000e+02
    ret i1 %result
}