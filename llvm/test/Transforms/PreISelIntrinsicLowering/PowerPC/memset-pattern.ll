; RUN: not opt -mtriple=powerpc64 -passes=pre-isel-intrinsic-lowering -S -o - %s 2>&1 | FileCheck %s

; CHECK: LLVM ERROR: memset_pattern.inline expansion not currently implemented for big-endian targets 

define void @memset_pattern_x(ptr %a, i128 %value, i64 %x) nounwind {
  tail call void @llvm.memset_pattern.p0.i64.i128(ptr %a, i128 %value, i64 %x, i1 0)
  ret void
}
