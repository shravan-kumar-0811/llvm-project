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
// AVX10 BF16 instructions
//-------------------------------------------------

// VADDNEPBF16, VSUBNEPBF16, VMULNEPBF16, VDIVNEPBF16, VMAXPBF16, VMINPBF16
multiclass avx10_fp_binopne_int_pbf16<bits<8> opc, string OpcodeStr,
                   X86SchedWriteSizes sched,
                   bit IsCommutable = 0> {
  let Predicates = [HasAVX10_2_512] in
    defm PBF16Z : avx512_fp_packed<opc, OpcodeStr,
                                !cast<Intrinsic>("int_x86_avx10_"#OpcodeStr#"pbf16512"),
                                !cast<Intrinsic>("int_x86_avx10_"#OpcodeStr#"pbf16512"),
                                v32bf16_info, sched.PH.ZMM, IsCommutable>, EVEX_V512,
                                T_MAP5, PD, EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_fp_packed<opc, OpcodeStr,
                                !cast<Intrinsic>("int_x86_avx10_"#OpcodeStr#"pbf16128"),
                                !cast<Intrinsic>("int_x86_avx10_"#OpcodeStr#"pbf16128"),
                                v8bf16x_info, sched.PH.XMM, IsCommutable>, EVEX_V128,
                                T_MAP5, PD, EVEX_CD8<16, CD8VF>;
    defm PBF16Z256 : avx512_fp_packed<opc, OpcodeStr,
                                !cast<Intrinsic>("int_x86_avx10_"#OpcodeStr#"pbf16256"),
                                !cast<Intrinsic>("int_x86_avx10_"#OpcodeStr#"pbf16256"),
                                v16bf16x_info, sched.PH.YMM, IsCommutable>, EVEX_V256,
                                T_MAP5, PD, EVEX_CD8<16, CD8VF>;
  }
}

multiclass avx10_fp_binop_pbf16<bits<8> opc, string OpcodeStr, SDPatternOperator OpNode,
                              X86SchedWriteSizes sched,
                              bit IsCommutable = 0,
                              SDPatternOperator MaskOpNode = OpNode> {
  let Predicates = [HasAVX10_2_512] in
    defm NEPBF16Z : avx512_fp_packed<opc, OpcodeStr, OpNode, MaskOpNode, 
                                v32bf16_info, sched.PH.ZMM, IsCommutable>, EVEX_V512,
                                T_MAP5, PD, EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm NEPBF16Z128 : avx512_fp_packed<opc, OpcodeStr, OpNode, MaskOpNode, 
                                v8bf16x_info, sched.PH.XMM, IsCommutable>, EVEX_V128,
                                T_MAP5, PD, EVEX_CD8<16, CD8VF>;
    defm NEPBF16Z256 : avx512_fp_packed<opc, OpcodeStr, OpNode, MaskOpNode, 
                                v16bf16x_info, sched.PH.YMM, IsCommutable>, EVEX_V256,
                                T_MAP5, PD, EVEX_CD8<16, CD8VF>;
  }
}

let Uses = []<Register>, mayRaiseFPException = 0 in {
defm VADD : avx10_fp_binop_pbf16<0x58, "vaddne", fadd, SchedWriteFAddSizes, 1>;
defm VSUB : avx10_fp_binop_pbf16<0x5C, "vsubne", fsub, SchedWriteFAddSizes, 0>;
defm VMUL : avx10_fp_binop_pbf16<0x59, "vmulne", fmul, SchedWriteFMulSizes, 0>;
defm VDIV : avx10_fp_binop_pbf16<0x5E, "vdivne", fdiv, SchedWriteFDivSizes, 0>;
defm VMIN : avx10_fp_binopne_int_pbf16<0x5D, "vmin", SchedWriteFCmpSizes, 0>;
defm VMAX : avx10_fp_binopne_int_pbf16<0x5F, "vmax", SchedWriteFCmpSizes, 0>;
}

// VCOMSBF16
let Uses = []<Register>, mayRaiseFPException = 0,
  Defs = [EFLAGS], Predicates = [HasAVX10_2_512] in {
  defm VCOMSBF16Z : sse12_ord_cmp<0x2F, FR16X, null_frag, bf16, f16mem, loadf16,
                              "comsbf16", SSEPackedSingle>, T_MAP5, PD, EVEX,
                              VEX_LIG, EVEX_CD8<16, CD8VT1>;

  let isCodeGenOnly = 1 in {
    defm VCOMSBF16Z : sse12_ord_cmp_int<0x2F, VR128X, X86comi, v8bf16, f16mem,
                            sse_load_bf16, "comsbf16", SSEPackedSingle>,
                            T_MAP5, PD, EVEX, VEX_LIG, EVEX_CD8<16, CD8VT1>;
  }
}

// VCMPPBF16
multiclass avx10_vcmp_common_bf16<X86FoldableSchedWrite sched, X86VectorVTInfo _> {
  let mayRaiseFPException = 0 in {
  defm  rri  : AVX512_maskable_cmp<0xC2, MRMSrcReg, _,
                   (outs _.KRC:$dst), (ins _.RC:$src1, _.RC:$src2, u8imm:$cc),
                   "vcmp"#_.Suffix,
                   "$cc, $src2, $src1", "$src1, $src2, $cc",
                   (X86cmpm (_.VT _.RC:$src1), (_.VT _.RC:$src2), timm:$cc),
                   (X86cmpm_su (_.VT _.RC:$src1), (_.VT _.RC:$src2), timm:$cc),
                   1>, Sched<[sched]>;

  defm  rmi  : AVX512_maskable_cmp<0xC2, MRMSrcMem, _,
                (outs _.KRC:$dst),(ins _.RC:$src1, _.MemOp:$src2, u8imm:$cc),
                "vcmp"#_.Suffix,
                "$cc, $src2, $src1", "$src1, $src2, $cc",
                (X86cmpm (_.VT _.RC:$src1), (_.VT (_.LdFrag addr:$src2)),
                         timm:$cc),
                (X86cmpm_su (_.VT _.RC:$src1), (_.VT (_.LdFrag addr:$src2)),
                            timm:$cc)>,
                Sched<[sched.Folded, sched.ReadAfterFold]>;

  defm  rmbi : AVX512_maskable_cmp<0xC2, MRMSrcMem, _,
                (outs _.KRC:$dst),
                (ins _.RC:$src1, _.ScalarMemOp:$src2, u8imm:$cc),
                "vcmp"#_.Suffix,
                "$cc, ${src2}"#_.BroadcastStr#", $src1",
                "$src1, ${src2}"#_.BroadcastStr#", $cc",
                (X86cmpm (_.VT _.RC:$src1),
                         (_.VT (_.BroadcastLdFrag addr:$src2)),
                         timm:$cc),
                (X86cmpm_su (_.VT _.RC:$src1),
                            (_.VT (_.BroadcastLdFrag addr:$src2)),
                            timm:$cc)>,
                EVEX_B, Sched<[sched.Folded, sched.ReadAfterFold]>;
  }
}

multiclass avx10_vcmp_bf16<X86SchedWriteWidths sched, AVX512VLVectorVTInfo _> {
  let Predicates = [HasAVX10_2_512] in
    defm Z   : avx10_vcmp_common_bf16<sched.ZMM, _.info512>, EVEX_V512;
  let Predicates = [HasAVX10_2] in {
   defm Z128 : avx10_vcmp_common_bf16<sched.XMM, _.info128>, EVEX_V128;
   defm Z256 : avx10_vcmp_common_bf16<sched.YMM, _.info256>, EVEX_V256;
  }
}

defm VCMPPBF16 : avx10_vcmp_bf16<SchedWriteFCmp, avx512vl_bf16_info>,
                          AVX512XDIi8Base, EVEX, VVVV, EVEX_CD8<16, CD8VF>, TA;


// VSQRTNEPBF16
multiclass avx10_sqrt_packed_bf16<bits<8> opc, string OpcodeStr,
                                  X86SchedWriteSizes sched> {
  let Predicates = [HasAVX10_2_512] in
  defm NEPBF16Z : avx512_sqrt_packed<opc, !strconcat(OpcodeStr, "pbf16"),
                                sched.PH.ZMM, v32bf16_info>,
                                EVEX_V512, PD, T_MAP5, EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm NEPBF16Z128 : avx512_sqrt_packed<opc, !strconcat(OpcodeStr, "pbf16"),
                                     sched.PH.XMM, v8bf16x_info>,
                                     EVEX_V128, PD, T_MAP5, EVEX_CD8<16, CD8VF>;
    defm NEPBF16Z256 : avx512_sqrt_packed<opc, !strconcat(OpcodeStr, "pbf16"),
                                     sched.PH.YMM, v16bf16x_info>,
                                     EVEX_V256, PD, T_MAP5, EVEX_CD8<16, CD8VF>;
  }
}

let Uses = []<Register>, mayRaiseFPException = 0 in
defm VSQRT : avx10_sqrt_packed_bf16<0x51, "vsqrtne", SchedWriteFSqrtSizes>;

// VRSQRTPBF16, VRCPPBF16, VSRQTPBF16, VGETEXPPBF16
multiclass avx10_fp14_pbf16<bits<8> opc, string OpcodeStr, SDNode OpNode,
                                X86SchedWriteWidths sched> {
  let Predicates = [HasAVX10_2_512] in
  defm PBF16Z : avx512_fp14_p<opc, !strconcat(OpcodeStr, "pbf16"),
                                OpNode, sched.ZMM, v32bf16_info>,
                                EVEX_V512;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_fp14_p<opc, !strconcat(OpcodeStr, "pbf16"),
                                OpNode, sched.XMM, v8bf16x_info>,
                                EVEX_V128;
    defm PBF16Z256 : avx512_fp14_p<opc, !strconcat(OpcodeStr, "pbf16"),
                                OpNode, sched.YMM, v16bf16x_info>,
                                EVEX_V256;
  }
}

defm VRSQRT  : avx10_fp14_pbf16<0x4E, "vrsqrt", X86rsqrt14, SchedWriteFRsqrt>,
                                     T_MAP6, PS, EVEX_CD8<16, CD8VF>;
defm VRCP    : avx10_fp14_pbf16<0x4C, "vrcp", X86rcp14, SchedWriteFRcp>,
                                     T_MAP6, PS, EVEX_CD8<16, CD8VF>;
defm VGETEXP : avx10_fp14_pbf16<0x42, "vgetexp", X86fgetexp, SchedWriteFRnd>,
                                     T_MAP5, EVEX_CD8<16, CD8VF>;

// VSCALEFPBF16
multiclass avx10_fp_scalef_bf16<bits<8> opc, string OpcodeStr,
                                X86SchedWriteWidths sched> {
  let Predicates = [HasAVX10_2_512] in
    defm PBF16Z : avx512_fp_scalef_p<opc, OpcodeStr, X86scalef, sched.ZMM, v32bf16_info>,
                                EVEX_V512, T_MAP6,PS, EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_fp_scalef_p<opc, OpcodeStr, X86scalef, sched.XMM, v8bf16x_info>,
                                   EVEX_V128, EVEX_CD8<16, CD8VF>, T_MAP6,PS;
    defm PBF16Z256 : avx512_fp_scalef_p<opc, OpcodeStr, X86scalef, sched.YMM, v16bf16x_info>,
                                   EVEX_V256, EVEX_CD8<16, CD8VF>, T_MAP6,PS;
  }
}

let Uses = []<Register>, mayRaiseFPException = 0 in
defm VSCALEF : avx10_fp_scalef_bf16<0x2C, "vscalef", SchedWriteFAdd>;

// VREDUCENEPBF16, VRNDSCALENEPBF16, VGETMANTPBF16
multiclass avx10_common_unary_fp_packed_imm_bf16<string OpcodeStr,
            AVX512VLVectorVTInfo _, bits<8> opc, SDPatternOperator OpNode,
            SDPatternOperator MaskOpNode, X86SchedWriteWidths sched> {
  let Predicates = [HasAVX10_2_512] in
    defm PBF16Z    : avx512_unary_fp_packed_imm<opc, OpcodeStr, OpNode, MaskOpNode,
                                           sched.ZMM, _.info512>, EVEX_V512;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_unary_fp_packed_imm<opc, OpcodeStr, OpNode, MaskOpNode,
                                           sched.XMM, _.info128>, EVEX_V128;
    defm PBF16Z256 : avx512_unary_fp_packed_imm<opc, OpcodeStr, OpNode, MaskOpNode,
                                           sched.YMM, _.info256>, EVEX_V256;
  }
}

let Uses = []<Register>, mayRaiseFPException = 0 in {
defm VREDUCENE : avx10_common_unary_fp_packed_imm_bf16<"vreducene", avx512vl_bf16_info, 0x56,
                            X86VReduce, X86VReduce, SchedWriteFRnd>,
                            AVX512XDIi8Base, TA, EVEX, EVEX_CD8<16, CD8VF>;
defm VRNDSCALENE : avx10_common_unary_fp_packed_imm_bf16<"vrndscalene", avx512vl_bf16_info, 0x08,
                            X86any_VRndScale, X86VRndScale, SchedWriteFRnd>,
                            AVX512XDIi8Base, TA, EVEX, EVEX_CD8<16, CD8VF>;
defm VGETMANT : avx10_common_unary_fp_packed_imm_bf16<"vgetmant", avx512vl_bf16_info, 0x26,
                            X86VGetMant, X86VGetMant, SchedWriteFRnd>,
                            AVX512XDIi8Base, TA, EVEX, EVEX_CD8<16, CD8VF>;
}

// VFPCLASSPBF16
multiclass avx10_fp_fpclass_bf16<string OpcodeStr, bits<8> opcVec,
                                  X86SchedWriteWidths sched> {
  let Predicates = [HasAVX10_2_512] in
    defm PBF16Z    : avx512_vector_fpclass<opcVec, OpcodeStr, sched.ZMM,
                                      avx512vl_bf16_info.info512, "z">, EVEX_V512;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_vector_fpclass<opcVec, OpcodeStr, sched.XMM,
                                      avx512vl_bf16_info.info128, "x">, EVEX_V128;
    defm PBF16Z256 : avx512_vector_fpclass<opcVec, OpcodeStr, sched.YMM,
                                      avx512vl_bf16_info.info256, "y">, EVEX_V256;
  }
}

// FIXME: need to set Uses = []<Register> but avx512_vector_fpclass has InstAlias.
defm VFPCLASS : avx10_fp_fpclass_bf16<"vfpclass", 0x66, SchedWriteFCmp>,
                                       AVX512XDIi8Base, TA, EVEX, EVEX_CD8<16, CD8VF>;

// VF[,N]M[ADD,SUB][132,213,231]NEPBF16
multiclass avx10_fma3p_213_bf16<bits<8> opc, string OpcodeStr,
                                 SDPatternOperator OpNode, SDNode MaskOpNode,
                                 X86SchedWriteWidths sched> {
  let Predicates = [HasAVX10_2_512] in
    defm PBF16Z : avx512_fma3p_213_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.ZMM, v32bf16_info>, EVEX_V512, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_fma3p_213_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.XMM, v8bf16x_info>, EVEX_V128, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
    defm PBF16Z256 : avx512_fma3p_213_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.YMM, v16bf16x_info>, EVEX_V256, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
  }
}

let Uses = []<Register>, mayRaiseFPException = 0 in {
defm VFMADD213NE : avx10_fma3p_213_bf16<0xA8, "vfmadd213nepbf16", any_fma,
                                         fma, SchedWriteFMA>;
defm VFMSUB213NE : avx10_fma3p_213_bf16<0xAA, "vfmsub213nepbf16", X86any_Fmsub,
                                         X86Fmsub, SchedWriteFMA>;
defm VFNMADD213NE : avx10_fma3p_213_bf16<0xAC, "vfnmadd213nepbf16", X86any_Fnmadd,
                                          X86Fnmadd, SchedWriteFMA>;
defm VFNMSUB213NE : avx10_fma3p_213_bf16<0xAE, "vfnmsub213nepbf16", X86any_Fnmsub,
                                          X86Fnmsub, SchedWriteFMA>;
}

multiclass avx10_fma3p_231_bf16<bits<8> opc, string OpcodeStr,
                                 SDPatternOperator OpNode, SDNode MaskOpNode,
                                 X86SchedWriteWidths sched> {
  let Predicates = [HasAVX10_2_512] in
    defm PBF16Z : avx512_fma3p_231_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.ZMM, v32bf16_info>, EVEX_V512, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_fma3p_231_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.XMM, v8bf16x_info>, EVEX_V128, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
    defm PBF16Z256 : avx512_fma3p_231_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.YMM, v16bf16x_info>, EVEX_V256, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
  }
}

let Uses = []<Register>, mayRaiseFPException = 0 in {
defm VFMADD231NE : avx10_fma3p_231_bf16<0xB8, "vfmadd231nepbf16", any_fma,
                                         fma, SchedWriteFMA>;
defm VFMSUB231NE : avx10_fma3p_231_bf16<0xBA, "vfmsub231nepbf16", X86any_Fmsub,
                                         X86Fmsub, SchedWriteFMA>;
defm VFNMADD231NE : avx10_fma3p_231_bf16<0xBC, "vfnmadd231nepbf16", X86any_Fnmadd,
                                          X86Fnmadd, SchedWriteFMA>;
defm VFNMSUB231NE : avx10_fma3p_231_bf16<0xBE, "vfnmsub231nepbf16", X86any_Fnmsub,
                                          X86Fnmsub, SchedWriteFMA>;
}

multiclass avx10_fma3p_132_bf16<bits<8> opc, string OpcodeStr,
                                 SDPatternOperator OpNode, SDNode MaskOpNode,
                                 X86SchedWriteWidths sched> {
  let Predicates = [HasAVX10_2_512] in
    defm PBF16Z : avx512_fma3p_132_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.ZMM, v32bf16_info>, EVEX_V512, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
  let Predicates = [HasAVX10_2] in {
    defm PBF16Z128 : avx512_fma3p_132_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                               sched.XMM, v8bf16x_info>, EVEX_V128, T_MAP6, PS,
                               EVEX_CD8<16, CD8VF>;
    defm PBF16Z256 : avx512_fma3p_132_rm<opc, OpcodeStr, OpNode, MaskOpNode,
                              sched.YMM, v16bf16x_info>, EVEX_V256, T_MAP6, PS,
                              EVEX_CD8<16, CD8VF>;
  }
}

let Uses = []<Register>, mayRaiseFPException = 0 in {
defm VFMADD132NE : avx10_fma3p_132_bf16<0x98, "vfmadd132nepbf16", any_fma,
                                         fma, SchedWriteFMA>;
defm VFMSUB132NE : avx10_fma3p_132_bf16<0x9A, "vfmsub132nepbf16", X86any_Fmsub,
                                         X86Fmsub, SchedWriteFMA>;
defm VFNMADD132NE : avx10_fma3p_132_bf16<0x9C, "vfnmadd132nepbf16", X86any_Fnmadd,
                                          X86Fnmadd, SchedWriteFMA>;
defm VFNMSUB132NE : avx10_fma3p_132_bf16<0x9E, "vfnmsub132nepbf16", X86any_Fnmsub,
                                          X86Fnmsub, SchedWriteFMA>;
}
