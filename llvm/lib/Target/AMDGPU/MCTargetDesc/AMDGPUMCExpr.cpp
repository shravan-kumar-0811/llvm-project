//===- AMDGPUMCExpr.cpp - AMDGPU specific MC expression classes -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "AMDGPUMCExpr.h"
#include "GCNSubtarget.h"
#include "Utils/AMDGPUBaseInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/Allocator.h"
#include "llvm/Support/KnownBits.h"
#include "llvm/Support/raw_ostream.h"
#include <optional>

using namespace llvm;
using namespace llvm::AMDGPU;

AMDGPUMCExpr::AMDGPUMCExpr(VariantKind Kind, ArrayRef<const MCExpr *> Args,
                           MCContext &Ctx)
    : Kind(Kind), Ctx(Ctx) {
  assert(Args.size() >= 1 && "Needs a minimum of one expression.");
  assert(Kind != AGVK_None && "Cannot construct AMDGPUMCExpr of kind none.");

  // Allocating the variadic arguments through the same allocation mechanism
  // that the object itself is allocated with so they end up in the same memory.
  //
  // Will result in an asan failure if allocated on the heap through standard
  // allocation (e.g., through SmallVector's grow).
  RawArgs = static_cast<const MCExpr **>(
      Ctx.allocate(sizeof(const MCExpr *) * Args.size()));
  std::uninitialized_copy(Args.begin(), Args.end(), RawArgs);
  this->Args = ArrayRef<const MCExpr *>(RawArgs, Args.size());
}

AMDGPUMCExpr::~AMDGPUMCExpr() { Ctx.deallocate(RawArgs); }

const AMDGPUMCExpr *AMDGPUMCExpr::create(VariantKind Kind,
                                         ArrayRef<const MCExpr *> Args,
                                         MCContext &Ctx) {
  return new (Ctx) AMDGPUMCExpr(Kind, Args, Ctx);
}

const MCExpr *AMDGPUMCExpr::getSubExpr(size_t Index) const {
  assert(Index < Args.size() && "Indexing out of bounds AMDGPUMCExpr sub-expr");
  return Args[Index];
}

void AMDGPUMCExpr::printImpl(raw_ostream &OS, const MCAsmInfo *MAI) const {
  switch (Kind) {
  default:
    llvm_unreachable("Unknown AMDGPUMCExpr kind.");
  case AGVK_Or:
    OS << "or(";
    break;
  case AGVK_Max:
    OS << "max(";
    break;
  case AGVK_ExtraSGPRs:
    OS << "extrasgprs(";
    break;
  case AGVK_TotalNumVGPRs:
    OS << "totalnumvgprs(";
    break;
  case AGVK_AlignTo:
    OS << "alignto(";
    break;
  case AGVK_Occupancy:
    OS << "occupancy(";
    break;
  }
  for (auto It = Args.begin(); It != Args.end(); ++It) {
    (*It)->print(OS, MAI, /*InParens=*/false);
    if ((It + 1) != Args.end())
      OS << ", ";
  }
  OS << ')';
}

static int64_t op(AMDGPUMCExpr::VariantKind Kind, int64_t Arg1, int64_t Arg2) {
  switch (Kind) {
  default:
    llvm_unreachable("Unknown AMDGPUMCExpr kind.");
  case AMDGPUMCExpr::AGVK_Max:
    return std::max(Arg1, Arg2);
  case AMDGPUMCExpr::AGVK_Or:
    return Arg1 | Arg2;
  }
}

bool AMDGPUMCExpr::evaluateExtraSGPRs(MCValue &Res, const MCAssembler *Asm,
                                      const MCFixup *Fixup) const {
  auto TryGetMCExprValue = [&](const MCExpr *Arg, uint64_t &ConstantValue) {
    MCValue MCVal;
    if (!Arg->evaluateAsRelocatable(MCVal, Asm, Fixup) || !MCVal.isAbsolute())
      return false;

    ConstantValue = MCVal.getConstant();
    return true;
  };

  assert(Args.size() == 3 &&
         "AMDGPUMCExpr Argument count incorrect for ExtraSGPRs");
  const MCSubtargetInfo *STI = Ctx.getSubtargetInfo();
  uint64_t VCCUsed = 0, FlatScrUsed = 0, XNACKUsed = 0;

  bool Success = TryGetMCExprValue(Args[2], XNACKUsed);

  assert(Success && "Arguments 3 for ExtraSGPRs should be a known constant");
  if (!Success || !TryGetMCExprValue(Args[0], VCCUsed) ||
      !TryGetMCExprValue(Args[1], FlatScrUsed))
    return false;

  uint64_t ExtraSGPRs = IsaInfo::getNumExtraSGPRs(
      STI, (bool)VCCUsed, (bool)FlatScrUsed, (bool)XNACKUsed);
  Res = MCValue::get(ExtraSGPRs);
  return true;
}

bool AMDGPUMCExpr::evaluateTotalNumVGPR(MCValue &Res, const MCAssembler *Asm,
                                        const MCFixup *Fixup) const {
  auto TryGetMCExprValue = [&](const MCExpr *Arg, uint64_t &ConstantValue) {
    MCValue MCVal;
    if (!Arg->evaluateAsRelocatable(MCVal, Asm, Fixup) || !MCVal.isAbsolute())
      return false;

    ConstantValue = MCVal.getConstant();
    return true;
  };
  assert(Args.size() == 2 &&
         "AMDGPUMCExpr Argument count incorrect for TotalNumVGPRs");
  const MCSubtargetInfo *STI = Ctx.getSubtargetInfo();
  uint64_t NumAGPR = 0, NumVGPR = 0;

  bool Has90AInsts = AMDGPU::isGFX90A(*STI);

  if (!TryGetMCExprValue(Args[0], NumAGPR) ||
      !TryGetMCExprValue(Args[1], NumVGPR))
    return false;

  uint64_t TotalNum = Has90AInsts && NumAGPR ? alignTo(NumVGPR, 4) + NumAGPR
                                             : std::max(NumVGPR, NumAGPR);
  Res = MCValue::get(TotalNum);
  return true;
}

bool AMDGPUMCExpr::evaluateAlignTo(MCValue &Res, const MCAssembler *Asm,
                                   const MCFixup *Fixup) const {
  auto TryGetMCExprValue = [&](const MCExpr *Arg, uint64_t &ConstantValue) {
    MCValue MCVal;
    if (!Arg->evaluateAsRelocatable(MCVal, Asm, Fixup) || !MCVal.isAbsolute())
      return false;

    ConstantValue = MCVal.getConstant();
    return true;
  };

  assert(Args.size() == 2 &&
         "AMDGPUMCExpr Argument count incorrect for AlignTo");
  uint64_t Value = 0, Align = 0;
  if (!TryGetMCExprValue(Args[0], Value) || !TryGetMCExprValue(Args[1], Align))
    return false;

  Res = MCValue::get(alignTo(Value, Align));
  return true;
}

bool AMDGPUMCExpr::evaluateOccupancy(MCValue &Res, const MCAssembler *Asm,
                                     const MCFixup *Fixup) const {
  auto TryGetMCExprValue = [&](const MCExpr *Arg, uint64_t &ConstantValue) {
    MCValue MCVal;
    if (!Arg->evaluateAsRelocatable(MCVal, Asm, Fixup) || !MCVal.isAbsolute())
      return false;

    ConstantValue = MCVal.getConstant();
    return true;
  };
  assert(Args.size() == 7 &&
         "AMDGPUMCExpr Argument count incorrect for Occupancy");
  uint64_t InitOccupancy, MaxWaves, Granule, TargetTotalNumVGPRs, Generation,
      NumSGPRs, NumVGPRs;

  bool Success = true;
  Success &= TryGetMCExprValue(Args[0], MaxWaves);
  Success &= TryGetMCExprValue(Args[1], Granule);
  Success &= TryGetMCExprValue(Args[2], TargetTotalNumVGPRs);
  Success &= TryGetMCExprValue(Args[3], Generation);
  Success &= TryGetMCExprValue(Args[4], InitOccupancy);

  assert(Success && "Arguments 1 to 5 for Occupancy should be known constants");

  if (!Success || !TryGetMCExprValue(Args[5], NumSGPRs) ||
      !TryGetMCExprValue(Args[6], NumVGPRs))
    return false;

  unsigned Occupancy = InitOccupancy;
  if (NumSGPRs)
    Occupancy = std::min(
        Occupancy, IsaInfo::getOccupancyWithNumSGPRs(
                       NumSGPRs, MaxWaves,
                       static_cast<AMDGPUSubtarget::Generation>(Generation)));
  if (NumVGPRs)
    Occupancy = std::min(Occupancy,
                         IsaInfo::getNumWavesPerEUWithNumVGPRs(
                             NumVGPRs, Granule, MaxWaves, TargetTotalNumVGPRs));

  Res = MCValue::get(Occupancy);
  return true;
}

bool AMDGPUMCExpr::evaluateAsRelocatableImpl(MCValue &Res,
                                             const MCAssembler *Asm,
                                             const MCFixup *Fixup) const {
  std::optional<int64_t> Total;
  switch (Kind) {
  default:
    break;
  case AGVK_ExtraSGPRs:
    return evaluateExtraSGPRs(Res, Asm, Fixup);
  case AGVK_AlignTo:
    return evaluateAlignTo(Res, Asm, Fixup);
  case AGVK_TotalNumVGPRs:
    return evaluateTotalNumVGPR(Res, Asm, Fixup);
  case AGVK_Occupancy:
    return evaluateOccupancy(Res, Asm, Fixup);
  }

  for (const MCExpr *Arg : Args) {
    MCValue ArgRes;
    if (!Arg->evaluateAsRelocatable(ArgRes, Asm, Fixup) || !ArgRes.isAbsolute())
      return false;

    if (!Total.has_value())
      Total = ArgRes.getConstant();
    Total = op(Kind, *Total, ArgRes.getConstant());
  }

  Res = MCValue::get(*Total);
  return true;
}

void AMDGPUMCExpr::visitUsedExpr(MCStreamer &Streamer) const {
  for (const MCExpr *Arg : Args)
    Streamer.visitUsedExpr(*Arg);
}

MCFragment *AMDGPUMCExpr::findAssociatedFragment() const {
  for (const MCExpr *Arg : Args) {
    if (Arg->findAssociatedFragment())
      return Arg->findAssociatedFragment();
  }
  return nullptr;
}

/// Allow delayed MCExpr resolve of ExtraSGPRs (in case VCCUsed or FlatScrUsed
/// are unresolvable but needed for further MCExprs). Derived from
/// implementation of IsaInfo::getNumExtraSGPRs in AMDGPUBaseInfo.cpp.
///
const AMDGPUMCExpr *AMDGPUMCExpr::createExtraSGPRs(const MCExpr *VCCUsed,
                                                   const MCExpr *FlatScrUsed,
                                                   bool XNACKUsed,
                                                   MCContext &Ctx) {

  return create(AGVK_ExtraSGPRs,
                {VCCUsed, FlatScrUsed, MCConstantExpr::create(XNACKUsed, Ctx)},
                Ctx);
}

const AMDGPUMCExpr *AMDGPUMCExpr::createTotalNumVGPR(const MCExpr *NumAGPR,
                                                     const MCExpr *NumVGPR,
                                                     MCContext &Ctx) {
  return create(AGVK_TotalNumVGPRs, {NumAGPR, NumVGPR}, Ctx);
}

/// Mimics GCNSubtarget::computeOccupancy for MCExpr.
///
/// Remove dependency on GCNSubtarget and depend only only the necessary values
/// for said occupancy computation. Should match computeOccupancy implementation
/// without passing \p STM on.
const AMDGPUMCExpr *AMDGPUMCExpr::createOccupancy(unsigned InitOcc,
                                                  const MCExpr *NumSGPRs,
                                                  const MCExpr *NumVGPRs,
                                                  const GCNSubtarget &STM,
                                                  MCContext &Ctx) {
  unsigned MaxWaves = IsaInfo::getMaxWavesPerEU(&STM);
  unsigned Granule = IsaInfo::getVGPRAllocGranule(&STM);
  unsigned TargetTotalNumVGPRs = IsaInfo::getTotalNumVGPRs(&STM);
  unsigned Generation = STM.getGeneration();

  auto CreateExpr = [&Ctx](unsigned Value) {
    return MCConstantExpr::create(Value, Ctx);
  };

  return create(AGVK_Occupancy,
                {CreateExpr(MaxWaves), CreateExpr(Granule),
                 CreateExpr(TargetTotalNumVGPRs), CreateExpr(Generation),
                 CreateExpr(InitOcc), NumSGPRs, NumVGPRs},
                Ctx);
}

static KnownBits fromOptionalToKnownBits(std::optional<bool> CompareResult) {
  const unsigned BitWidth = 64;
  const APInt True(BitWidth, 1, /*isSigned=*/false);
  const APInt False(BitWidth, 0, /*isSigned=*/false);
  if (CompareResult) {
    return *CompareResult ? KnownBits::makeConstant(True)
                          : KnownBits::makeConstant(False);
  }

  KnownBits UnknownBool(/*BitWidth=*/1);
  return UnknownBool.zext(BitWidth);
}

using KnownBitsMap = std::unordered_map<const MCExpr *, KnownBits>;

void KnownBitsMapHelper(const MCExpr *Expr, KnownBitsMap &KBM, unsigned depth) {
  const unsigned BitWidth = 64;
  const APInt False(BitWidth, 0, /*isSigned=*/false);

  int64_t Val;
  if (Expr->evaluateAsAbsolute(Val)) {
    APInt APValue(BitWidth, Val, /*isSigned=*/true);
    KBM[Expr] = KnownBits::makeConstant(APValue);
    return;
  }

  if (depth == 0) {
    KBM[Expr] = KnownBits(BitWidth);
    return;
  }

  depth--;

  switch (Expr->getKind()) {
  case MCExpr::ExprKind::Binary: {
    const MCBinaryExpr *BExpr = cast<MCBinaryExpr>(Expr);
    const MCExpr *LHS = BExpr->getLHS();
    const MCExpr *RHS = BExpr->getRHS();

    KnownBitsMapHelper(LHS, KBM, depth);
    KnownBitsMapHelper(RHS, KBM, depth);
    KnownBits LHSKnown = KBM[LHS];
    KnownBits RHSKnown = KBM[RHS];
    std::optional<bool> CompareRes;

    switch (BExpr->getOpcode()) {
    default:
      KBM[Expr] = KnownBits(BitWidth);
      return;
    case MCBinaryExpr::Opcode::Add:
      KBM[Expr] =
          KnownBits::computeForAddSub(/*Add=*/true, /*NSW=*/false,
                                      /*NUW=*/false, LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::And:
      KBM[Expr] = LHSKnown & RHSKnown;
      return;
    case MCBinaryExpr::Opcode::Div:
      KBM[Expr] = KnownBits::sdiv(LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::EQ:
      CompareRes = KnownBits::eq(LHSKnown, RHSKnown);
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    case MCBinaryExpr::Opcode::NE:
      CompareRes = KnownBits::ne(LHSKnown, RHSKnown);
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    case MCBinaryExpr::Opcode::GT:
      CompareRes = KnownBits::sgt(LHSKnown, RHSKnown);
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    case MCBinaryExpr::Opcode::GTE:
      CompareRes = KnownBits::sge(LHSKnown, RHSKnown);
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    case MCBinaryExpr::Opcode::LAnd: {
      std::optional<bool> LHSBool =
          KnownBits::ne(LHSKnown, KnownBits::makeConstant(False));
      std::optional<bool> RHSBool =
          KnownBits::ne(RHSKnown, KnownBits::makeConstant(False));
      if (LHSBool && RHSBool) {
        CompareRes = *LHSBool && *RHSBool;
      }
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    }
    case MCBinaryExpr::Opcode::LOr: {
      KnownBits Bits = LHSKnown | RHSKnown;
      CompareRes = KnownBits::ne(Bits, KnownBits::makeConstant(False));
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    }
    case MCBinaryExpr::Opcode::LT:
      CompareRes = KnownBits::slt(LHSKnown, RHSKnown);
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    case MCBinaryExpr::Opcode::LTE:
      CompareRes = KnownBits::sle(LHSKnown, RHSKnown);
      KBM[Expr] = fromOptionalToKnownBits(CompareRes);
      return;
    case MCBinaryExpr::Opcode::Mod:
      KBM[Expr] = KnownBits::srem(LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::Mul:
      KBM[Expr] = KnownBits::mul(LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::Or:
      KBM[Expr] = LHSKnown | RHSKnown;
      return;
    case MCBinaryExpr::Opcode::Shl:
      KBM[Expr] = KnownBits::shl(LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::AShr:
      KBM[Expr] = KnownBits::ashr(LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::LShr:
      KBM[Expr] = KnownBits::lshr(LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::Sub:
      KBM[Expr] =
          KnownBits::computeForAddSub(/*Add=*/false, /*NSW=*/false,
                                      /*NUW=*/false, LHSKnown, RHSKnown);
      return;
    case MCBinaryExpr::Opcode::Xor:
      KBM[Expr] = LHSKnown ^ RHSKnown;
      return;
    }
  }
  case MCExpr::ExprKind::Constant: {
    const MCConstantExpr *CE = cast<MCConstantExpr>(Expr);
    APInt APValue(BitWidth, CE->getValue(), /*isSigned=*/true);
    KBM[Expr] = KnownBits::makeConstant(APValue);
    return;
  }
  case MCExpr::ExprKind::SymbolRef: {
    const MCSymbolRefExpr *RExpr = cast<MCSymbolRefExpr>(Expr);
    const MCSymbol &Sym = RExpr->getSymbol();
    if (!Sym.isVariable()) {
      KBM[Expr] = KnownBits(BitWidth);
      return;
    }

    // Variable value retrieval is not for actual use but only for knownbits
    // analysis.
    KnownBitsMapHelper(Sym.getVariableValue(/*SetUsed=*/false), KBM, depth);
    KBM[Expr] = KBM[Sym.getVariableValue(/*SetUsed=*/false)];
    return;
  }
  case MCExpr::ExprKind::Unary: {
    const MCUnaryExpr *UExpr = cast<MCUnaryExpr>(Expr);
    KnownBitsMapHelper(UExpr->getSubExpr(), KBM, depth);
    KnownBits KB = KBM[UExpr->getSubExpr()];

    switch (UExpr->getOpcode()) {
    default:
      KBM[Expr] = KnownBits(BitWidth);
      return;
    case MCUnaryExpr::Opcode::Minus: {
      KB.makeNegative();
      KBM[Expr] = KB;
      return;
    }
    case MCUnaryExpr::Opcode::Not: {
      KnownBits AllOnes(BitWidth);
      AllOnes.setAllOnes();
      KBM[Expr] = KB ^ AllOnes;
      return;
    }
    case MCUnaryExpr::Opcode::Plus: {
      KB.makeNonNegative();
      KBM[Expr] = KB;
      return;
    }
    }
  }
  case MCExpr::ExprKind::Target: {
    const AMDGPUMCExpr *AGVK = cast<AMDGPUMCExpr>(Expr);

    switch (AGVK->getKind()) {
    default:
      KBM[Expr] = KnownBits(BitWidth);
      return;
    case AMDGPUMCExpr::VariantKind::AGVK_Or: {
      KnownBitsMapHelper(AGVK->getSubExpr(0), KBM, depth);
      KnownBits KB = KBM[AGVK->getSubExpr(0)];
      for (const MCExpr *Arg : AGVK->getArgs()) {
        KnownBitsMapHelper(Arg, KBM, depth);
        KB |= KBM[Arg];
      }
      KBM[Expr] = KB;
      return;
    }
    case AMDGPUMCExpr::VariantKind::AGVK_Max: {
      KnownBitsMapHelper(AGVK->getSubExpr(0), KBM, depth);
      KnownBits KB = KBM[AGVK->getSubExpr(0)];
      for (const MCExpr *Arg : AGVK->getArgs()) {
        KnownBitsMapHelper(Arg, KBM, depth);
        KB = KnownBits::umax(KB, KBM[Arg]);
      }
      KBM[Expr] = KB;
      return;
    }
    case AMDGPUMCExpr::VariantKind::AGVK_ExtraSGPRs:
    case AMDGPUMCExpr::VariantKind::AGVK_TotalNumVGPRs:
    case AMDGPUMCExpr::VariantKind::AGVK_AlignTo:
    case AMDGPUMCExpr::VariantKind::AGVK_Occupancy: {
      int64_t Val;
      if (AGVK->evaluateAsAbsolute(Val)) {
        APInt APValue(BitWidth, Val, /*isSigned=*/false);
        KBM[Expr] = KnownBits::makeConstant(APValue);
        return;
      }
      KBM[Expr] = KnownBits(BitWidth);
      return;
    }
    }
  }
  }
}

static const MCExpr *TryFoldHelper(const MCExpr *Expr, KnownBitsMap &KBM,
                                   MCContext &Ctx) {
  if (!KBM.count(Expr))
    return Expr;

  auto valueCheckKnownBits = [](KnownBits &KB, unsigned Value) -> bool {
    if (!KB.isConstant())
      return false;

    return Value == KB.getConstant();
  };

  if (Expr->getKind() == MCExpr::ExprKind::Constant)
    return Expr;

  // Resolving unary operations to constants may make the value more ambiguous.
  // For example, `~62` becomes `-63`; however, to me it's more ambiguous if a
  // bit mask value is represented through a negative number.
  if (Expr->getKind() != MCExpr::ExprKind::Unary) {
    if (KBM[Expr].isConstant()) {
      APInt ConstVal = KBM[Expr].getConstant();
      return MCConstantExpr::create(ConstVal.getSExtValue(), Ctx);
    }

    int64_t EvalValue;
    if (Expr->evaluateAsAbsolute(EvalValue)) {
      return MCConstantExpr::create(EvalValue, Ctx);
    }
  }

  switch (Expr->getKind()) {
  default:
    return Expr;
  case MCExpr::ExprKind::Binary: {
    const MCBinaryExpr *BExpr = cast<MCBinaryExpr>(Expr);
    const MCExpr *LHS = BExpr->getLHS();
    const MCExpr *RHS = BExpr->getRHS();

    switch (BExpr->getOpcode()) {
    default:
      return Expr;
    case MCBinaryExpr::Opcode::Sub: {
      if (valueCheckKnownBits(KBM[RHS], 0)) {
        return TryFoldHelper(LHS, KBM, Ctx);
      }
      break;
    }
    case MCBinaryExpr::Opcode::Add:
    case MCBinaryExpr::Opcode::Or: {
      if (valueCheckKnownBits(KBM[LHS], 0)) {
        return TryFoldHelper(RHS, KBM, Ctx);
      }
      if (valueCheckKnownBits(KBM[RHS], 0)) {
        return TryFoldHelper(LHS, KBM, Ctx);
      }
      break;
    }
    case MCBinaryExpr::Opcode::Mul: {
      if (valueCheckKnownBits(KBM[LHS], 1)) {
        return TryFoldHelper(RHS, KBM, Ctx);
      }
      if (valueCheckKnownBits(KBM[RHS], 1)) {
        return TryFoldHelper(LHS, KBM, Ctx);
      }
      break;
    }
    case MCBinaryExpr::Opcode::Shl:
    case MCBinaryExpr::Opcode::AShr:
    case MCBinaryExpr::Opcode::LShr: {
      if (valueCheckKnownBits(KBM[RHS], 0)) {
        return TryFoldHelper(LHS, KBM, Ctx);
      }
      if (valueCheckKnownBits(KBM[LHS], 0)) {
        return MCConstantExpr::create(0, Ctx);
      }
      break;
    }
    case MCBinaryExpr::Opcode::And: {
      if (valueCheckKnownBits(KBM[LHS], 0) ||
          valueCheckKnownBits(KBM[RHS], 0)) {
        return MCConstantExpr::create(0, Ctx);
      }
      break;
    }
    }
    const MCExpr *NewLHS = TryFoldHelper(LHS, KBM, Ctx);
    const MCExpr *NewRHS = TryFoldHelper(RHS, KBM, Ctx);
    if (NewLHS != LHS || NewRHS != RHS) {
      return MCBinaryExpr::create(BExpr->getOpcode(), NewLHS, NewRHS, Ctx,
                                  BExpr->getLoc());
    }
    return Expr;
  }
  case MCExpr::ExprKind::Unary: {
    const MCUnaryExpr *UExpr = cast<MCUnaryExpr>(Expr);
    const MCExpr *SubExpr = UExpr->getSubExpr();
    const MCExpr *NewSubExpr = TryFoldHelper(SubExpr, KBM, Ctx);
    if (SubExpr != NewSubExpr)
      return MCUnaryExpr::create(UExpr->getOpcode(), NewSubExpr, Ctx,
                                 UExpr->getLoc());
    return Expr;
  }
  case MCExpr::ExprKind::Target: {
    const AMDGPUMCExpr *AGVK = cast<AMDGPUMCExpr>(Expr);
    SmallVector<const MCExpr *, 8> NewArgs;
    bool Changed = false;
    for (const MCExpr *Arg : AGVK->getArgs()) {
      const MCExpr *NewArg = TryFoldHelper(Arg, KBM, Ctx);
      NewArgs.push_back(NewArg);
      Changed |= Arg != NewArg;
    }
    return Changed ? AMDGPUMCExpr::create(AGVK->getKind(), NewArgs, Ctx) : Expr;
  }
  }
  return Expr;
}

const MCExpr *llvm::TryFold(const MCExpr *Expr, MCContext &Ctx) {
  KnownBitsMap KBM;
  KnownBitsMapHelper(Expr, KBM, /*depth=*/16);
  const MCExpr *NewExpr = TryFoldHelper(Expr, KBM, Ctx);

  return Expr != NewExpr ? NewExpr : Expr;
}

void llvm::AMDGPUMCExprPrint(const MCExpr *Expr, raw_ostream &OS,
                             const MCAsmInfo *MAI) {
  int64_t Val;
  if (Expr->evaluateAsAbsolute(Val)) {
    OS << Val;
    return;
  }

  Expr->print(OS, MAI);
}
