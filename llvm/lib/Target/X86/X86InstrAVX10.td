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
// Integer truncate and extend operations
//-------------------------------------------------

multiclass avx10_sat_cvt_rmb<bits<8> Opc, string OpStr, X86FoldableSchedWrite sched,
                              X86VectorVTInfo DestInfo,
                              X86VectorVTInfo SrcInfo,
                              SDNode MaskNode> {
  defm rr: AVX512_maskable<Opc, MRMSrcReg, DestInfo, (outs DestInfo.RC:$dst),
                         (ins SrcInfo.RC:$src), OpStr, "$src", "$src",
                         (DestInfo.VT (MaskNode SrcInfo.RC:$src))>, Sched<[sched]>;
  defm rm: AVX512_maskable<Opc, MRMSrcMem, DestInfo, (outs DestInfo.RC:$dst),
                         (ins SrcInfo.MemOp:$src), OpStr, "$src", "$src",
                         (DestInfo.VT (MaskNode (SrcInfo.VT
                         (SrcInfo.LdFrag addr:$src))))>,
                         Sched<[sched.Folded, sched.ReadAfterFold]>;
  defm rmb: AVX512_maskable<Opc, MRMSrcMem, DestInfo, (outs DestInfo.RC:$dst),
                         (ins SrcInfo.ScalarMemOp:$src), OpStr,
                         "${src}"#SrcInfo.BroadcastStr, "${src}"#SrcInfo.BroadcastStr,
                         (DestInfo.VT (MaskNode (SrcInfo.VT
                         (SrcInfo.BroadcastLdFrag addr:$src))))>, EVEX_B,
                         Sched<[sched.Folded, sched.ReadAfterFold]>;
}

// Conversion with rounding control (RC)
multiclass avx10_sat_cvt_rc<bits<8> Opc, string OpStr, X86SchedWriteWidths sched,
                             AVX512VLVectorVTInfo DestInfo, AVX512VLVectorVTInfo SrcInfo,
                             SDNode MaskNode> {
    let Uses = [MXCSR] in
    defm Zrrb : AVX512_maskable<Opc, MRMSrcReg, DestInfo.info512,
                              (outs DestInfo.info512.RC:$dst),
                              (ins SrcInfo.info512.RC:$src, AVX512RC:$rc),
                              OpStr, "$rc, $src", "$src, $rc",
                              (DestInfo.info512.VT (MaskNode
                               SrcInfo.info512.RC:$src, (i32 timm:$rc)))>,
                              Sched<[sched.ZMM]>, EVEX, EVEX_RC, EVEX_B;
    let Predicates = [HasAVX10_2], hasEVEX_U = 1 in {
    defm Z256rrb : AVX512_maskable<Opc, MRMSrcReg, DestInfo.info256,
                              (outs DestInfo.info256.RC:$dst),
                              (ins SrcInfo.info256.RC:$src, AVX512RC:$rc),
                              OpStr, "$rc, $src", "$src, $rc",
                              (DestInfo.info256.VT (MaskNode
                               SrcInfo.info256.RC:$src, (i32 timm:$rc)))>,
                              Sched<[sched.YMM]>, EVEX, EVEX_RC, EVEX_B;
    }
}

// Conversion with SAE
multiclass
    avx10_sat_cvt_sae<bits<8> Opc, string OpStr, X86SchedWriteWidths sched,
                      AVX512VLVectorVTInfo DestInfo, AVX512VLVectorVTInfo SrcInfo,
                      SDNode Node> {
    let Uses = [MXCSR] in
    defm Zrrb : AVX512_maskable<Opc, MRMSrcReg, DestInfo.info512,
                              (outs DestInfo.info512.RC:$dst),
                              (ins SrcInfo.info512.RC:$src),
                              OpStr, "{sae}, $src", "$src, {sae}",
                              (DestInfo.info512.VT (Node SrcInfo.info512.RC:$src))>,
                              Sched<[sched.ZMM]>, EVEX, EVEX_B;
    let Predicates = [HasAVX10_2], hasEVEX_U = 1 in {
    defm Z256rrb : AVX512_maskable<Opc, MRMSrcReg, DestInfo.info256,
                              (outs DestInfo.info256.RC:$dst),
                              (ins SrcInfo.info256.RC:$src),
                              OpStr, "{sae}, $src", "$src, {sae}",
                              (DestInfo.info256.VT (Node SrcInfo.info256.RC:$src))>,
                              Sched<[sched.YMM]>, EVEX, EVEX_B;
    }
}

multiclass avx10_sat_cvt_base<bits<8> Opc, string OpStr, X86SchedWriteWidths sched,
                               SDNode MaskNode, AVX512VLVectorVTInfo DestInfo,
                               AVX512VLVectorVTInfo SrcInfo> {
  let Predicates = [HasAVX10_2_512] in
  defm Z : avx10_sat_cvt_rmb<Opc, OpStr, sched.ZMM,
           DestInfo.info512, SrcInfo.info512,
           MaskNode>,
      EVEX, EVEX_V512;
  let Predicates = [HasAVX10_2] in {
    defm Z256
        : avx10_sat_cvt_rmb<Opc, OpStr, sched.YMM,
           DestInfo.info256, SrcInfo.info256,
          MaskNode>,
          EVEX, EVEX_V256;
    defm Z128
        : avx10_sat_cvt_rmb<Opc, OpStr, sched.XMM,
          DestInfo.info128, SrcInfo.info128,
          MaskNode>,
          EVEX, EVEX_V128;
  }
}

defm VCVTNEBF162IBS : avx10_sat_cvt_base<0x69, "vcvtnebf162ibs",
                      SchedWriteVecIMul, X86vcvtnebf162ibs,
                      avx512vl_i16_info, avx512vl_bf16_info>,
                      AVX512XDIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;
defm VCVTNEBF162IUBS : avx10_sat_cvt_base<0x6b, "vcvtnebf162iubs",
                      SchedWriteVecIMul, X86vcvtnebf162iubs,
                      avx512vl_i16_info, avx512vl_bf16_info>,
                      AVX512XDIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;

defm VCVTPH2IBS : avx10_sat_cvt_base<0x69, "vcvtph2ibs", SchedWriteVecIMul,
                  X86vcvtph2ibs, avx512vl_i16_info,
                  avx512vl_f16_info>, AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;
defm VCVTPH2IBS : avx10_sat_cvt_rc<0x69, "vcvtph2ibs", SchedWriteVecIMul,
                   avx512vl_i16_info, avx512vl_f16_info,
                   X86vcvtph2ibsRnd>,
                   AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;

defm VCVTPH2IUBS : avx10_sat_cvt_base<0x6b, "vcvtph2iubs", SchedWriteVecIMul,
                   X86vcvtph2iubs, avx512vl_i16_info,
                   avx512vl_f16_info>, AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;
defm VCVTPH2IUBS : avx10_sat_cvt_rc<0x6b, "vcvtph2iubs", SchedWriteVecIMul,
                   avx512vl_i16_info, avx512vl_f16_info,
                   X86vcvtph2iubsRnd>,
                   AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;

defm VCVTPS2IBS : avx10_sat_cvt_base<0x69, "vcvtps2ibs", SchedWriteVecIMul,
                  X86vcvtps2ibs, avx512vl_i32_info,
                  avx512vl_f32_info>, AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;
defm VCVTPS2IBS : avx10_sat_cvt_rc<0x69, "vcvtps2ibs", SchedWriteVecIMul,
                   avx512vl_i32_info, avx512vl_f32_info,
                   X86vcvtps2ibsRnd>,
                   AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;

defm VCVTPS2IUBS : avx10_sat_cvt_base<0x6b, "vcvtps2iubs", SchedWriteVecIMul,
                   X86vcvtps2iubs, avx512vl_i32_info,
                   avx512vl_f32_info>, AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;
defm VCVTPS2IUBS : avx10_sat_cvt_rc<0x6b, "vcvtps2iubs", SchedWriteVecIMul,
                   avx512vl_i32_info, avx512vl_f32_info,
                   X86vcvtps2iubsRnd>,
                   AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;


defm VCVTTNEBF162IBS : avx10_sat_cvt_base<0x68, "vcvttnebf162ibs",
                      SchedWriteVecIMul, X86vcvttnebf162ibs,
                      avx512vl_i16_info, avx512vl_bf16_info>,
                      AVX512XDIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;
defm VCVTTNEBF162IUBS : avx10_sat_cvt_base<0x6a, "vcvttnebf162iubs",
                      SchedWriteVecIMul, X86vcvttnebf162iubs,
                      avx512vl_i16_info, avx512vl_bf16_info>,
                      AVX512XDIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;

defm VCVTTPH2IBS : avx10_sat_cvt_base<0x68, "vcvttph2ibs", SchedWriteVecIMul,
                   X86vcvttph2ibs, avx512vl_i16_info,
                   avx512vl_f16_info>, AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;
defm VCVTTPH2IBS : avx10_sat_cvt_sae<0x68, "vcvttph2ibs", SchedWriteVecIMul,
                   avx512vl_i16_info, avx512vl_f16_info, X86vcvttph2ibsSAE>,
                   AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;
defm VCVTTPH2IUBS : avx10_sat_cvt_base<0x6a, "vcvttph2iubs", SchedWriteVecIMul,
                   X86vcvttph2iubs, avx512vl_i16_info, avx512vl_f16_info>,
                   AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;
defm VCVTTPH2IUBS : avx10_sat_cvt_sae<0x6a, "vcvttph2iubs", SchedWriteVecIMul,
                   avx512vl_i16_info, avx512vl_f16_info, X86vcvttph2iubsSAE>,
                   AVX512PSIi8Base, T_MAP5, EVEX_CD8<16, CD8VF>;


defm VCVTTPS2IBS : avx10_sat_cvt_base<0x68, "vcvttps2ibs", SchedWriteVecIMul,
                   X86vcvttps2ibs, avx512vl_i32_info, avx512vl_f32_info>,
                   AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;
defm VCVTTPS2IBS : avx10_sat_cvt_sae<0x68, "vcvttps2ibs", SchedWriteVecIMul,
                   avx512vl_i32_info, avx512vl_f32_info, X86vcvttps2ibsSAE>,
                   AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;

defm VCVTTPS2IUBS : avx10_sat_cvt_base<0x6a, "vcvttps2iubs", SchedWriteVecIMul,
                   X86vcvttps2iubs, avx512vl_i32_info, avx512vl_f32_info>,
                   AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;
defm VCVTTPS2IUBS : avx10_sat_cvt_sae<0x6a, "vcvttps2iubs", SchedWriteVecIMul,
                   avx512vl_i32_info, avx512vl_f32_info, X86vcvttps2iubsSAE>,
                   AVX512PDIi8Base, T_MAP5, EVEX_CD8<32, CD8VF>;
