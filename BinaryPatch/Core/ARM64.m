#import "ARM64.h"
#import "MemoryAccess.h"

#include <stdint.h>

#pragma mark - Instruction recognition

bool pxqARM64IsADRP(
    uint32_t insn,
    uint32_t *rd
)
{
    if ((insn & 0x9F000000u) != 0x90000000u)
        return false;

    if (rd)
        *rd = insn & 0x1Fu;

    return true;
}


bool pxqARM64IsLDR64UnsignedImmediate(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *imm12
)
{
    /*
     * LDR Xt, [Xn, #imm]
     */
    if ((insn & 0xFFC00000u) != 0xF9400000u)
        return false;

    if (rt)
        *rt = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (imm12)
        *imm12 = (insn >> 10) & 0xFFFu;

    return true;
}


bool pxqARM64IsLDR64Register(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *rm
)
{
    /*
     * LDR Xt, [Xn, Xm]
     */
    if ((insn & 0xFFE00C00u) != 0xF8600800u)
        return false;

    if (rt)
        *rt = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (rm)
        *rm = (insn >> 16) & 0x1Fu;

    return true;
}


bool pxqARM64IsSTR64Register(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *rm
)
{
    /*
     * STR Xt, [Xn, Xm]
     */
    if ((insn & 0xFFE00C00u) != 0xF8200800u)
        return false;

    if (rt)
        *rt = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (rm)
        *rm = (insn >> 16) & 0x1Fu;

    return true;
}


bool pxqARM64IsBL(
    uint32_t insn
)
{
    return (insn & 0xFC000000u) == 0x94000000u;
}


bool pxqARM64IsB(
    uint32_t insn
)
{
    return (insn & 0xFC000000u) == 0x14000000u;
}


#pragma mark - Instruction decoding

bool pxqARM64DecodeADD64RegisterNoShift(
    uint32_t insn,
    uint32_t *rd,
    uint32_t *rn,
    uint32_t *rm
)
{
    /*
     * ADD Xd, Xn, Xm
     *
     * 64-bit, no flags, LSL #0.
     */
    if ((insn & 0xFFE0FC00u) != 0x8B000000u)
        return false;

    if (rd)
        *rd = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (rm)
        *rm = (insn >> 16) & 0x1Fu;

    return true;
}


bool pxqARM64DecodeADD64ImmediateNoShift(
    uint32_t insn,
    uint32_t *rd,
    uint32_t *rn,
    uint32_t *imm12
)
{
    /*
     * ADD Xd, Xn, #imm12
     *
     * 64-bit, no flags, shift = 0.
     */
    if ((insn & 0xFFC00000u) != 0x91000000u)
        return false;

    if (rd)
        *rd = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (imm12)
        *imm12 = (insn >> 10) & 0xFFFu;

    return true;
}


bool pxqARM64DecodeMoveRegister(
    uint32_t insn,
    uint32_t *destinationRegister,
    uint32_t *sourceRegister
)
{
    /*
     * MOV Xd, Xn
     *
     * Actual encoding:
     *   ORR Xd, XZR, Xn
     */
    if ((insn & 0xFFE0FFE0u) != 0xAA0003E0u)
        return false;

    if (destinationRegister)
        *destinationRegister = insn & 0x1Fu;

    if (sourceRegister)
        *sourceRegister = (insn >> 16) & 0x1Fu;

    return true;
}


bool pxqARM64IsMoveRegister(
    uint32_t insn,
    uint32_t destinationRegister,
    uint32_t sourceRegister
)
{
    uint32_t decodedDestination = 0;
    uint32_t decodedSource = 0;

    if (!pxqARM64DecodeMoveRegister(
            insn,
            &decodedDestination,
            &decodedSource)) {

        return false;
    }

    return
        decodedDestination == destinationRegister &&
        decodedSource == sourceRegister;
}


bool pxqARM64DecodeLDUR64(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    int32_t *imm9
)
{
    /*
     * LDUR Xt, [Xn, #simm9]
     */
    if ((insn & 0xFFE00C00u) != 0xF8400000u)
        return false;

    uint32_t raw =
        (insn >> 12) & 0x1FFu;

    int32_t signedImm =
        (raw & 0x100u)
            ? (int32_t)(raw | 0xFFFFFE00u)
            : (int32_t)raw;

    if (rt)
        *rt = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (imm9)
        *imm9 = signedImm;

    return true;
}


bool pxqARM64DecodeBLR(
    uint32_t insn,
    uint32_t *rn
)
{
    /*
     * BLR Xn
     */
    if ((insn & 0xFFFFFC1Fu) != 0xD63F0000u)
        return false;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    return true;
}


bool pxqARM64DecodeADRP(
    uint32_t insn,
    uintptr_t pc,
    uint32_t *rd,
    uintptr_t *target
)
{
    if (!pxqARM64IsADRP(insn, rd))
        return false;

    uint32_t immlo =
        (insn >> 29) & 0x3u;

    uint32_t immhi =
        (insn >> 5) & 0x7FFFFu;

    int64_t imm21 =
        ((int64_t)immhi << 2) | immlo;

    /*
     * sign extend 21-bit immediate
     */
    if (imm21 & (1LL << 20))
        imm21 |= ~((1LL << 21) - 1);

    uintptr_t page =
        pc & ~(uintptr_t)0xFFF;

    intptr_t delta =
        (intptr_t)(imm21 << 12);

    if (target)
        *target = page + delta;

    return true;
}


bool pxqARM64DecodeBLTarget(
    uint32_t insn,
    uintptr_t pc,
    uintptr_t *target
)
{
    if (!pxqARM64IsBL(insn))
        return false;

    int64_t imm26 =
        (int64_t)(insn & 0x03FFFFFFu);

    if (imm26 & 0x02000000)
        imm26 |= ~0x03FFFFFFLL;

    intptr_t delta =
        (intptr_t)(imm26 << 2);

    if (target)
        *target = pc + delta;

    return true;
}


bool pxqARM64DecodeBranchTarget(
    uint32_t insn,
    uintptr_t pc,
    uintptr_t *target
)
{
    if (!pxqARM64IsB(insn))
        return false;

    int64_t imm26 =
        (int64_t)(insn & 0x03FFFFFFu);

    if (imm26 & 0x02000000)
        imm26 |= ~0x03FFFFFFLL;

    intptr_t delta =
        (intptr_t)(imm26 << 2);

    if (target)
        *target = pc + delta;

    return true;
}


bool pxqARM64DecodeTBNZ(
    uint32_t insn,
    uintptr_t pc,
    uint32_t *rt,
    uint32_t *bitNumber,
    uintptr_t *target
)
{
    /*
     * TBNZ <Wt|Xt>, #bit, <target>
     *
     * Ignore b5, b40, imm14 and Rt while validating only the
     * TBNZ opcode itself. The decoded bit number determines
     * whether the instruction uses the W or X form.
     */
    if ((insn & 0x7F000000u) != 0x37000000u)
        return false;

    uint32_t decodedRt =
        insn & 0x1Fu;

    uint32_t decodedBitNumber =
        ((insn >> 19) & 0x1Fu) |
        ((insn >> 26) & 0x20u);

    int64_t imm14 =
        (int64_t)((insn >> 5) & 0x3FFFu);

    if (imm14 & 0x2000)
        imm14 |= ~0x3FFFLL;

    uintptr_t decodedTarget = 0;

    if (!pxqAddressAddSignedOffset(
            pc,
            imm14 << 2,
            &decodedTarget)) {

        return false;
    }

    if (rt)
        *rt = decodedRt;

    if (bitNumber)
        *bitNumber = decodedBitNumber;

    if (target)
        *target = decodedTarget;

    return true;
}


#pragma mark - Instruction encoding

bool pxqARM64EncodeB(
    uintptr_t source,
    uintptr_t target,
    uint32_t *instruction
)
{
    intptr_t delta =
        (intptr_t)target -
        (intptr_t)source;

    /*
     * B:
     *
     * signed imm26 << 2
     *
     * range:
     *   -128 MiB
     *   through
     *   +128 MiB - 4 bytes
     */
    if ((delta & 0x3) != 0)
        return false;

    if (delta < -(1LL << 27) ||
        delta > ((1LL << 27) - 4)) {

        return false;
    }

    int64_t imm26 =
        ((int64_t)delta) >> 2;

    *instruction =
        0x14000000u |
        ((uint32_t)imm26 & 0x03FFFFFFu);

    return true;
}


bool pxqARM64EncodeBL(
    uintptr_t source,
    uintptr_t target,
    uint32_t *instruction
)
{
    intptr_t delta =
        (intptr_t)target -
        (intptr_t)source;

    /*
     * BL:
     *
     * signed imm26 << 2
     *
     * range:
     *   -128 MiB
     *   through
     *   +128 MiB - 4 bytes
     */
    if ((delta & 0x3) != 0)
        return false;

    if (delta < -(1LL << 27) ||
        delta > ((1LL << 27) - 4)) {

        return false;
    }

    int64_t imm26 =
        ((int64_t)delta) >> 2;

    *instruction =
        0x94000000u |
        ((uint32_t)imm26 & 0x03FFFFFFu);

    return true;
}


bool pxqARM64EncodeMOVZ32(
    uint32_t rd,
    uint16_t imm16,
    uint32_t *instruction
)
{
    /*
     * MOV Wd, #imm16
     *
     * Alias of:
     *
     *   MOVZ Wd, #imm16
     *
     * hw = 0
     */
    if (rd > 31)
        return false;

    *instruction =
        0x52800000u |
        ((uint32_t)imm16 << 5) |
        rd;

    return true;
}
