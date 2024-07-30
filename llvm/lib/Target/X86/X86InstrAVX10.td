//===-- X86InstrAVX10.td - AVX10 Instruction Set -----------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the X86 AVX10 instruction set, defining the
// instructions, and properties of the instructions which are needed for code
// generation, machine code emission, and analysis.
//
//===----------------------------------------------------------------------===//

// VMPSADBW
defm VMPSADBW : avx512_common_3Op_rm_imm8<0x42, X86Vmpsadbw, "vmpsadbw", SchedWritePSADBW,
                                          avx512vl_i16_info, avx512vl_i8_info,
                                          HasAVX10_2>,
                    XS, EVEX_CD8<32, CD8VF>;

// YMM Rounding
multiclass avx256_fp_binop_p_round<bits<8> opc, string OpcodeStr, SDNode OpNodeRnd,
                                   X86SchedWriteSizes sched> {
  defm PHZ256 : avx512_fp_round_packed<opc, OpcodeStr, OpNodeRnd, sched.PH.YMM,
                                       v16f16x_info>, T_MAP5,PS, EVEX_CD8<16, CD8VF>;
  defm PSZ256 : avx512_fp_round_packed<opc, OpcodeStr, OpNodeRnd, sched.PS.YMM,
                                       v8f32x_info>, TB, PS, EVEX_CD8<32, CD8VF>;
  defm PDZ256 : avx512_fp_round_packed<opc, OpcodeStr, OpNodeRnd, sched.PD.YMM,
                                       v4f64x_info>, TB, PD, EVEX_CD8<64, CD8VF>, REX_W;
}

let Predicates = [HasAVX10_2], hasEVEX_U = 1, OpEnc = EncEVEX in
  defm VADD : avx256_fp_binop_p_round<0x58, "vadd", X86faddRnd, SchedWriteFAddSizes>;

//-------------------------------------------------
// AVX10 CONVERT instructions
//-------------------------------------------------

multiclass avx10_cvt2ps2ph_rc<bits<8> opc, string OpcodeStr, X86FoldableSchedWrite sched,
                                  X86VectorVTInfo _Src, X86VectorVTInfo _,
                                  SDNode OpNodeRnd> {
  let Uses = [MXCSR] in
    defm rrb : AVX512_maskable<opc, MRMSrcReg, _, (outs _.RC:$dst),
                            (ins _Src.RC:$src1, _Src.RC:$src2, AVX512RC:$rc), OpcodeStr,
                            "$rc, $src2, $src1", "$src1, $src2, $rc",
                            (_.VT (OpNodeRnd (_Src.VT _Src.RC:$src1),
                                             (_Src.VT _Src.RC:$src2), (i32 timm:$rc)))>,
                            EVEX, VVVV, EVEX_B, EVEX_RC, PD, Sched<[sched]>;
}

multiclass avx10_convert_3op<bits<8> opc, string OpcodeStr,
                             X86SchedWriteWidths sched,
                             AVX512VLVectorVTInfo _SrcVTInfo,
                             AVX512VLVectorVTInfo _DstVTInfo,
                             SDNode OpNode, SDNode OpNodeRnd> {
  let Predicates = [HasAVX10_2_512], Uses = [MXCSR] in {
    defm Z : avx512_binop_rm2<opc, OpcodeStr, sched.ZMM, OpNode,
                                   _SrcVTInfo.info512, _DstVTInfo.info512,
                                   _SrcVTInfo.info512>,
             avx10_cvt2ps2ph_rc<opc, OpcodeStr, sched.ZMM,
                                 _SrcVTInfo.info512, _DstVTInfo.info512,
                                 OpNodeRnd>,
                                 EVEX_V512, EVEX_CD8<32, CD8VF>;
  }
  let Predicates = [HasAVX10_2] in {
    defm Z256 : avx512_binop_rm2<opc, OpcodeStr, sched.YMM, OpNode,
                                      _SrcVTInfo.info256, _DstVTInfo.info256,
                                      _SrcVTInfo.info256>,
                                      EVEX_V256, EVEX_CD8<32, CD8VF>;
    defm Z128 : avx512_binop_rm2<opc, OpcodeStr, sched.XMM, OpNode,
                                      _SrcVTInfo.info128, _DstVTInfo.info128,
                                      _SrcVTInfo.info128>,
                                      EVEX_V128, EVEX_CD8<32, CD8VF>;
  }

  let Predicates = [HasAVX10_2], hasEVEX_U = 1 in {
    defm Z256 : avx10_cvt2ps2ph_rc<opc, OpcodeStr, sched.YMM,
                                    _SrcVTInfo.info256, _DstVTInfo.info256,
                                    OpNodeRnd>;
  }
}

defm VCVT2PS2PHX : avx10_convert_3op<0x67, "vcvt2ps2phx",
                                    SchedWriteCvtPD2PS, // FIXME: Using SchedWriteCvtPD2PS is a workaround.
                                    avx512vl_f32_info, avx512vl_f16_info,
                                    X86vcvt2ps2phx, X86vcvt2ps2phxRnd>, T8;

multiclass avx10_binop_all2<bits<8> opc, string OpcodeStr,
                             X86SchedWriteWidths sched,
                             AVX512VLVectorVTInfo _SrcVTInfo,
                             AVX512VLVectorVTInfo _DstVTInfo,
                             SDNode OpNode,
                             bit IsCommutable = 0> {
  let Predicates = [HasAVX10_2_512] in
    defm NAME#Z : avx512_binop_rm2<opc, OpcodeStr, sched.ZMM, OpNode,
                                   _SrcVTInfo.info512, _DstVTInfo.info512,
                                   _SrcVTInfo.info512, IsCommutable>,
                                   EVEX_V512;
  let Predicates = [HasAVX10_2] in {
    defm NAME#Z256 : avx512_binop_rm2<opc, OpcodeStr, sched.YMM, OpNode,
                                      _SrcVTInfo.info256, _DstVTInfo.info256,
                                      _SrcVTInfo.info256, IsCommutable>,
                                     EVEX_V256;
    defm NAME#Z128 : avx512_binop_rm2<opc, OpcodeStr, sched.XMM, OpNode,
                                      _SrcVTInfo.info128, _DstVTInfo.info128,
                                      _SrcVTInfo.info128, IsCommutable>,
                                      EVEX_V128;
  }
}

defm VCVTNE2PH2BF8 : avx10_binop_all2<0x74, "vcvtne2ph2bf8",
                       SchedWriteCvtPD2PS,
                       avx512vl_f16_info, avx512vl_i8_info, X86vcvtne2ph2bf8,
                       0>, EVEX_CD8<16, CD8VF>, T8, XD;
defm VCVTNE2PH2BF8S : avx10_binop_all2<0x74, "vcvtne2ph2bf8s",
                       SchedWriteCvtPD2PS,
                       avx512vl_f16_info, avx512vl_i8_info, X86vcvtne2ph2bf8s,
                       0>, EVEX_CD8<16, CD8VF>, T_MAP5, XD;
defm VCVTNE2PH2HF8 : avx10_binop_all2<0x18, "vcvtne2ph2hf8",
                       SchedWriteCvtPD2PS,
                       avx512vl_f16_info, avx512vl_i8_info, X86vcvtne2ph2hf8,
                       0>, EVEX_CD8<16, CD8VF>, T_MAP5, XD;
defm VCVTNE2PH2HF8S : avx10_binop_all2<0x1b, "vcvtne2ph2hf8s",
                       SchedWriteCvtPD2PS,
                       avx512vl_f16_info, avx512vl_i8_info, X86vcvtne2ph2hf8s,
                       0>, EVEX_CD8<16, CD8VF>, T_MAP5, XD;

multiclass avx10_convert_fp8_2op_nomb_packed<bits<8> opc, string OpcodeStr,
                           X86VectorVTInfo _dest, X86VectorVTInfo _src,
                           SDNode OpNode,
                           X86MemOperand x86memop,
                           X86FoldableSchedWrite sched,
                           dag ld_dag = (load addr:$src)> {
  let ExeDomain = _dest.ExeDomain in {
  defm rr : AVX512_maskable_split<opc, MRMSrcReg, _dest ,(outs _dest.RC:$dst),
                          (ins _src.RC:$src), OpcodeStr, "$src", "$src",
                          (OpNode (_src.VT _src.RC:$src)),
                          (OpNode (_src.VT _src.RC:$src))>,
                          Sched<[sched]>;
  defm rm : AVX512_maskable_split<opc, MRMSrcMem, _dest, (outs _dest.RC:$dst),
                          (ins x86memop:$src), OpcodeStr, "$src", "$src",
                          (OpNode (_src.VT ld_dag)),
                          (OpNode (_src.VT ld_dag))>,
                          Sched<[sched.Folded]>;
  }
}

multiclass avx10_convert_fp8_2op_nomb<string OpcodeStr, AVX512VLVectorVTInfo _dest,
             AVX512VLVectorVTInfo _src, bits<8> opc, SDNode OpNode> {
  let Predicates = [HasAVX10_2_512] in
  defm Z : avx10_convert_fp8_2op_nomb_packed<opc, OpcodeStr, _dest.info512,
                              _src.info256, OpNode, f256mem, WriteCvtPH2PSZ>, EVEX_V512;
  let Predicates = [HasAVX10_2] in {
  defm Z128 : avx10_convert_fp8_2op_nomb_packed<opc, OpcodeStr, _dest.info128,
                              _src.info128, OpNode, f64mem, WriteCvtPH2PSZ>, EVEX_V128;
  defm Z256 : avx10_convert_fp8_2op_nomb_packed<opc, OpcodeStr, _dest.info256,
                              _src.info128, OpNode, f128mem, WriteCvtPH2PSZ>, EVEX_V256;
  }
}

defm VCVTHF82PH : avx10_convert_fp8_2op_nomb<"vcvthf82ph", avx512vl_f16_info,
                      avx512vl_i8_info, 0x1e, X86vcvthf82ph>,
                      AVX512XDIi8Base, T_MAP5, EVEX, EVEX_CD8<16, CD8VH>;

multiclass avx10_convert_fp8_3op_packed<bits<8> OpCode, string OpcodeStr,
           X86VectorVTInfo vt_dst, X86VectorVTInfo vt_src1,
           X86VectorVTInfo vt_src2, SDPatternOperator OpNode,
           SDPatternOperator MaskOpNode, X86FoldableSchedWrite sched,
           string Broadcast = vt_src2.BroadcastStr,
           X86MemOperand MemOp = vt_src2.MemOp,
           RegisterClass MaskRC = vt_src2.KRCWM,
           dag LdDAG = (vt_dst.VT (OpNode (vt_src1.VT vt_src1.RC:$src1), (vt_src2.VT (vt_src2.LdFrag addr:$src2)))),
           dag MaskLdDAG = (vt_dst.VT (MaskOpNode (vt_src1.VT vt_src1.RC:$src1), (vt_src2.VT (vt_src2.LdFrag addr:$src2))))> {
  defm rr : AVX512_maskable_cvt<OpCode, MRMSrcReg, vt_dst, (outs vt_dst.RC:$dst),
                      (ins vt_src1.RC:$src1, vt_src2.RC:$src2),
                      (ins vt_dst.RC:$src0, MaskRC:$mask, vt_src1.RC:$src1, vt_src2.RC:$src2),
                      (ins MaskRC:$mask, vt_src1.RC:$src1, vt_src2.RC:$src2),
                      OpcodeStr, "$src2, $src1", "$src1, $src2",
                      (vt_dst.VT (OpNode (vt_src1.VT vt_src1.RC:$src1), (vt_src2.VT vt_src2.RC:$src2))),
                      (vselect_mask MaskRC:$mask,
                        (vt_dst.VT (MaskOpNode (vt_src1.VT vt_src1.RC:$src1), (vt_src2.VT vt_src2.RC:$src2))),
                        vt_dst.RC:$src0),
                      (vselect_mask MaskRC:$mask,
                        (vt_dst.VT (MaskOpNode (vt_src1.VT vt_src1.RC:$src1), (vt_src2.VT vt_src2.RC:$src2))),
                        vt_dst.ImmAllZerosV)>,
                      EVEX, VVVV, Sched<[sched]>;
  let mayLoad = 1 in
  defm rm : AVX512_maskable_cvt<OpCode, MRMSrcMem, vt_dst, (outs vt_dst.RC:$dst),
                      (ins vt_src1.RC:$src1, MemOp:$src2),
                      (ins vt_dst.RC:$src0, MaskRC:$mask, vt_src1.RC:$src1, MemOp:$src2),
                      (ins MaskRC:$mask, vt_src1.RC:$src1, MemOp:$src2),
                      OpcodeStr, "$src2, $src1", "$src1, $src2",
                      LdDAG,
                      (vselect_mask MaskRC:$mask, MaskLdDAG, vt_dst.RC:$src0),
                      (vselect_mask MaskRC:$mask, MaskLdDAG, vt_dst.ImmAllZerosV)>,
                      EVEX, VVVV, Sched<[sched]>;

  let mayLoad = 1 in
  defm rmb : AVX512_maskable_cvt<OpCode, MRMSrcMem, vt_dst, (outs vt_dst.RC:$dst),
                      (ins vt_src1.RC:$src1, vt_src2.ScalarMemOp:$src2),
                      (ins vt_dst.RC:$src0, MaskRC:$mask, vt_src1.RC:$src1, vt_src2.ScalarMemOp:$src2),
                      (ins MaskRC:$mask, vt_src1.RC:$src1, vt_src2.ScalarMemOp:$src2), OpcodeStr,
                      "${src2}"#Broadcast#", $src1", "$src1, ${src2}"#Broadcast,
                      (vt_dst.VT (OpNode (vt_src1.VT vt_src1.RC:$src1), (vt_src2.VT
                                  (vt_src2.BroadcastLdFrag addr:$src2)))),
                      (vselect_mask MaskRC:$mask,
                                       (vt_dst.VT
                                        (MaskOpNode
                                         (vt_src1.VT vt_src1.RC:$src1), (vt_src2.VT
                                          (vt_src2.BroadcastLdFrag addr:$src2)))),
                                       vt_dst.RC:$src0),
                      (vselect_mask MaskRC:$mask,
                                       (vt_dst.VT
                                        (MaskOpNode
                                         (vt_src1.VT vt_src1.RC:$src1),
                                         (vt_src2.VT
                                          (vt_src2.BroadcastLdFrag addr:$src2)))),
                                       vt_dst.ImmAllZerosV)>,
                      EVEX, VVVV, EVEX_B, Sched<[sched]>;
}

multiclass avx10_convert_fp8_3op<bits<8> OpCode, string OpcodeStr,
           AVX512VLVectorVTInfo vt_dst, AVX512VLVectorVTInfo vt_src,
           X86SchedWriteWidths sched,
           SDPatternOperator OpNode,
           SDPatternOperator MaskOpNode,
           PatFrag bcast128 = vt_src.info128.BroadcastLdFrag,
           PatFrag loadVT128 = vt_src.info128.LdFrag,
           RegisterClass maskRC128 = vt_src.info128.KRCWM> {
  let Predicates = [HasAVX10_2_512] in
    defm Z : avx10_convert_fp8_3op_packed<OpCode, OpcodeStr, vt_dst.info256,
               vt_dst.info512, vt_src.info512, OpNode, OpNode, sched.ZMM>,
               EVEX_V512, EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm Z256 : avx10_convert_fp8_3op_packed<OpCode, OpcodeStr, vt_dst.info128,
                  vt_dst.info256, vt_src.info256, OpNode, OpNode, sched.YMM>,
                  EVEX_V256, EVEX_CD8<16, CD8VF>;
    defm Z128 : avx10_convert_fp8_3op_packed<OpCode, OpcodeStr, vt_dst.info128,
                  vt_dst.info128, vt_src.info128,
                  null_frag, null_frag, sched.XMM>,
                  EVEX_V128, EVEX_CD8<16, CD8VF>;
    // Special patterns to allow use of MaskOpNode for masking 128 version. Instruction
    // patterns have been disabled with null_frag.
    def : Pat<(vt_dst.info128.VT (OpNode (vt_dst.info128.VT VR128X:$src1),
                                         (vt_src.info128.VT VR128X:$src2))),
              (!cast<Instruction>(NAME # "Z128rr") VR128X:$src1, VR128X:$src2)>;
    def : Pat<(MaskOpNode (vt_dst.info128.VT VR128X:$src1),
                          (vt_src.info128.VT VR128X:$src2),
                          (vt_dst.info128.VT VR128X:$src0), maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rrk") VR128X:$src0, maskRC128:$mask,
                          VR128X:$src1, VR128X:$src2)>;
    def : Pat<(MaskOpNode (vt_dst.info128.VT VR128X:$src1),
                          (vt_src.info128.VT VR128X:$src2),
                          vt_dst.info128.ImmAllZerosV, maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rrkz") maskRC128:$mask,
                          VR128X:$src1, VR128X:$src2)>;

    def : Pat<(vt_dst.info128.VT (OpNode (vt_dst.info128.VT VR128X:$src1),
                                         (loadVT128 addr:$src2))),
              (!cast<Instruction>(NAME # "Z128rm") VR128X:$src1, addr:$src2)>;
    def : Pat<(MaskOpNode (vt_dst.info128.VT VR128X:$src1),
                          (loadVT128 addr:$src2),
                          (vt_dst.info128.VT VR128X:$src0),
                          maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmk") VR128X:$src0, maskRC128:$mask,
                          VR128X:$src1, addr:$src2)>;
    def : Pat<(MaskOpNode (vt_dst.info128.VT VR128X:$src1),
                          (loadVT128 addr:$src2),
                          vt_dst.info128.ImmAllZerosV,
                          maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmkz") maskRC128:$mask,
                          VR128X:$src1, addr:$src2)>;

    def : Pat<(vt_dst.info128.VT (OpNode (vt_dst.info128.VT VR128X:$src1),
                                         (vt_src.info128.VT (bcast128 addr:$src2)))),
              (!cast<Instruction>(NAME # "Z128rmb") VR128X:$src1, addr:$src2)>;
    def : Pat<(MaskOpNode (vt_dst.info128.VT VR128X:$src1),
                          (vt_src.info128.VT (bcast128 addr:$src2)),
                          (vt_dst.info128.VT VR128X:$src0), maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmbk") VR128X:$src0, maskRC128:$mask,
                           VR128X:$src1, addr:$src2)>;
    def : Pat<(MaskOpNode (vt_dst.info128.VT VR128X:$src1),
                          (vt_src.info128.VT (bcast128 addr:$src2)),
                          vt_dst.info128.ImmAllZerosV, maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmbkz") maskRC128:$mask,
                           VR128X:$src1, addr:$src2)>;
  }
}

defm VCVTBIASPH2BF8 : avx10_convert_fp8_3op<0x74, "vcvtbiasph2bf8",
                        avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtbiasph2bf8, X86vmcvtbiasph2bf8>,
                        T8,PS;
defm VCVTBIASPH2BF8S : avx10_convert_fp8_3op<0x74, "vcvtbiasph2bf8s",
                         avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtbiasph2bf8s, X86vmcvtbiasph2bf8s>,
                         T_MAP5,PS;
defm VCVTBIASPH2HF8 : avx10_convert_fp8_3op<0x18, "vcvtbiasph2hf8",
                        avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtbiasph2hf8, X86vmcvtbiasph2hf8>,
                        T_MAP5,PS;
defm VCVTBIASPH2HF8S : avx10_convert_fp8_3op<0x1b, "vcvtbiasph2hf8s",
                         avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtbiasph2hf8s, X86vmcvtbiasph2hf8s>,
                         T_MAP5,PS;

multiclass avx10_convert_fp8_2op_packed<bits<8> OpCode, string OpcodeStr,
           X86VectorVTInfo vt_dst, X86VectorVTInfo vt_src, SDPatternOperator OpNode,
           SDPatternOperator MaskOpNode, X86FoldableSchedWrite sched,
           string Alias, string Broadcast = vt_src.BroadcastStr,
           X86MemOperand MemOp = vt_src.MemOp,
           RegisterClass MaskRC = vt_src.KRCWM,
           dag LdDAG = (vt_dst.VT (OpNode (vt_src.VT (vt_src.LdFrag addr:$src)))),
           dag MaskLdDAG = (vt_dst.VT (MaskOpNode (vt_src.VT (vt_src.LdFrag addr:$src))))> {
  defm rr : AVX512_maskable_cvt<OpCode, MRMSrcReg, vt_dst, (outs vt_dst.RC:$dst),
                      (ins vt_src.RC:$src),
                      (ins vt_dst.RC:$src0, MaskRC:$mask, vt_src.RC:$src),
                      (ins MaskRC:$mask, vt_src.RC:$src),
                      OpcodeStr, "$src", "$src",
                      (vt_dst.VT (OpNode (vt_src.VT vt_src.RC:$src))),
                      (vselect_mask MaskRC:$mask,
                                       (vt_dst.VT (MaskOpNode (vt_src.VT vt_src.RC:$src))),
                                       vt_dst.RC:$src0),
                      (vselect_mask MaskRC:$mask,
                                       (vt_dst.VT (MaskOpNode (vt_src.VT vt_src.RC:$src))),
                                       vt_dst.ImmAllZerosV)>, EVEX, Sched<[sched]>;

  defm rm : AVX512_maskable_cvt<OpCode, MRMSrcMem, vt_dst, (outs vt_dst.RC:$dst),
                      (ins MemOp:$src),
                      (ins vt_dst.RC:$src0, MaskRC:$mask, MemOp:$src),
                      (ins MaskRC:$mask, MemOp:$src),
                      OpcodeStr#Alias, "$src", "$src",
                      LdDAG,
                      (vselect_mask MaskRC:$mask, MaskLdDAG, vt_dst.RC:$src0),
                      (vselect_mask MaskRC:$mask, MaskLdDAG, vt_dst.ImmAllZerosV)>,
                      EVEX, Sched<[sched]>;

  defm rmb : AVX512_maskable_cvt<OpCode, MRMSrcMem, vt_dst, (outs vt_dst.RC:$dst),
                      (ins vt_src.ScalarMemOp:$src),
                      (ins vt_dst.RC:$src0, MaskRC:$mask, vt_src.ScalarMemOp:$src),
                      (ins MaskRC:$mask, vt_src.ScalarMemOp:$src), OpcodeStr,
                      "${src}"#Broadcast, "${src}"#Broadcast,
                      (vt_dst.VT (OpNode (vt_src.VT
                                  (vt_src.BroadcastLdFrag addr:$src)))),
                      (vselect_mask MaskRC:$mask,
                                       (vt_dst.VT
                                        (MaskOpNode
                                         (vt_src.VT
                                          (vt_src.BroadcastLdFrag addr:$src)))),
                                       vt_dst.RC:$src0),
                      (vselect_mask MaskRC:$mask,
                                       (vt_dst.VT
                                        (MaskOpNode
                                         (vt_src.VT
                                          (vt_src.BroadcastLdFrag addr:$src)))),
                                       vt_dst.ImmAllZerosV)>,
                      EVEX, EVEX_B, Sched<[sched]>;

  // Allow rr with the x, y suffix.
  def : InstAlias<OpcodeStr#Alias#
                  "\t{$src, $dst|$dst, $src}",
                  (!cast<Instruction>(NAME#"rr")
                   vt_dst.RC:$dst, vt_src.RC:$src), 0, "att">;
  def : InstAlias<OpcodeStr#Alias#
                  "\t{$src, $dst {${mask}}|$dst {${mask}}, $src}",
                  (!cast<Instruction>(NAME#"rrk")
                   vt_dst.RC:$dst, vt_dst.KRCWM:$mask, vt_src.RC:$src),
                   0, "att">;
  def : InstAlias<OpcodeStr#Alias#
                  "\t{$src, $dst {${mask}} {z}|$dst {${mask}} {z}, $src}",
                  (!cast<Instruction>(NAME#"rrkz")
                   vt_dst.RC:$dst, vt_dst.KRCWM:$mask, vt_src.RC:$src),
                   0, "att">;

  // Allow rmb with the x, y suffix.
  def : InstAlias<OpcodeStr#Alias#
                  "\t{${src}"#vt_src.BroadcastStr#", $dst|$dst, ${src}"#
                  vt_src.BroadcastStr#"}",
                  (!cast<Instruction>(NAME#"rmb")
                   vt_dst.RC:$dst, vt_src.ScalarMemOp:$src), 0, "att">;
  def : InstAlias<OpcodeStr#Alias#
                  "\t{${src}"#vt_src.BroadcastStr#", $dst {${mask}}|"
                  "$dst {${mask}}, ${src}"#vt_src.BroadcastStr#"}",
                  (!cast<Instruction>(NAME#"rmbk")
                   vt_dst.RC:$dst, vt_dst.KRCWM:$mask, vt_src.ScalarMemOp:$src),
                   0, "att">;
  def : InstAlias<OpcodeStr#Alias#
                  "\t{${src}"#vt_src.BroadcastStr#", $dst {${mask}} {z}|"
                  "$dst {${mask}} {z}, ${src}"#vt_src.BroadcastStr#"}",
                  (!cast<Instruction>(NAME#"rmbkz")
                   vt_dst.RC:$dst, vt_dst.KRCWM:$mask, vt_src.ScalarMemOp:$src),
                   0, "att">;
}

multiclass avx10_convert_fp8_2op<bits<8> OpCode, string OpcodeStr,
           AVX512VLVectorVTInfo vt_dst, AVX512VLVectorVTInfo vt_src,
           X86SchedWriteWidths sched,
           SDPatternOperator OpNode,
           SDPatternOperator MaskOpNode,
           PatFrag bcast128 = vt_src.info128.BroadcastLdFrag,
           PatFrag loadVT128 = vt_src.info128.LdFrag,
           RegisterClass maskRC128 = vt_src.info128.KRCWM> {
  let Predicates = [HasAVX10_2_512] in
    defm Z : avx10_convert_fp8_2op_packed<OpCode, OpcodeStr, vt_dst.info256,
               vt_src.info512, OpNode, OpNode, sched.ZMM,
               "">,
               EVEX_V512, EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm Z256 : avx10_convert_fp8_2op_packed<OpCode, OpcodeStr, vt_dst.info128,
                  vt_src.info256, OpNode, OpNode, sched.YMM,
                  "{y}">,
                  EVEX_V256, EVEX_CD8<16, CD8VF>;
    defm Z128 : avx10_convert_fp8_2op_packed<OpCode, OpcodeStr, vt_dst.info128,
                  vt_src.info128,
                  null_frag, null_frag, sched.XMM,
                  "{x}">,
                  EVEX_V128, EVEX_CD8<16, CD8VF>;
    // Special patterns to allow use of MaskOpNode for masking 128 version. Instruction
    // patterns have been disabled with null_frag.
    def : Pat<(vt_dst.info128.VT (OpNode (vt_src.info128.VT VR128X:$src))),
              (!cast<Instruction>(NAME # "Z128rr") VR128X:$src)>;
    def : Pat<(MaskOpNode (vt_src.info128.VT VR128X:$src), (vt_dst.info128.VT VR128X:$src0),
                            maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rrk") VR128X:$src0, maskRC128:$mask, VR128X:$src)>;
    def : Pat<(MaskOpNode (vt_src.info128.VT VR128X:$src), vt_dst.info128.ImmAllZerosV,
                            maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rrkz") maskRC128:$mask, VR128X:$src)>;

    def : Pat<(vt_dst.info128.VT (OpNode (loadVT128 addr:$src))),
              (!cast<Instruction>(NAME # "Z128rm") addr:$src)>;
    def : Pat<(MaskOpNode (loadVT128 addr:$src), (vt_dst.info128.VT VR128X:$src0),
                            maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmk") VR128X:$src0, maskRC128:$mask, addr:$src)>;
    def : Pat<(MaskOpNode (loadVT128 addr:$src), vt_dst.info128.ImmAllZerosV,
                            maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmkz") maskRC128:$mask, addr:$src)>;

    def : Pat<(vt_dst.info128.VT (OpNode (vt_src.info128.VT (bcast128 addr:$src)))),
              (!cast<Instruction>(NAME # "Z128rmb") addr:$src)>;
    def : Pat<(MaskOpNode (vt_src.info128.VT (bcast128 addr:$src)),
                            (vt_dst.info128.VT VR128X:$src0), maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmbk") VR128X:$src0, maskRC128:$mask, addr:$src)>;
    def : Pat<(MaskOpNode (vt_src.info128.VT (bcast128 addr:$src)),
                            vt_dst.info128.ImmAllZerosV, maskRC128:$mask),
              (!cast<Instruction>(NAME # "Z128rmbkz") maskRC128:$mask, addr:$src)>;
  }
}

defm VCVTNEPH2BF8 : avx10_convert_fp8_2op<0x74, "vcvtneph2bf8",
                      avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtneph2bf8, X86vmcvtneph2bf8>,
                      T8,XS;
defm VCVTNEPH2BF8S : avx10_convert_fp8_2op<0x74, "vcvtneph2bf8s",
                       avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtneph2bf8s, X86vmcvtneph2bf8s>,
                       T_MAP5,XS;
defm VCVTNEPH2HF8 : avx10_convert_fp8_2op<0x18, "vcvtneph2hf8",
                      avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtneph2hf8, X86vmcvtneph2hf8>,
                      T_MAP5,XS;
defm VCVTNEPH2HF8S : avx10_convert_fp8_2op<0x1b, "vcvtneph2hf8s",
                       avx512vl_i8_info, avx512vl_f16_info, SchedWriteCvtPD2PS,
                        X86vcvtneph2hf8s, X86vmcvtneph2hf8s>,
                       T_MAP5,XS;