#import "pxQoLARM64.h"

#import <Foundation/Foundation.h>
#import <mach/mach.h>
#include <stdint.h>

#pragma mark - Instruction helpers

bool pxQoLIsADRP(uint32_t insn, uint32_t *rd)
{
    if ((insn & 0x9F000000u) != 0x90000000u)
        return NO;

    if (rd)
        *rd = insn & 0x1Fu;

    return YES;
}


bool pxQoLIsLDR64UnsignedImm(uint32_t insn,
                                  uint32_t *rt,
                                  uint32_t *rn,
                                  uint32_t *imm12)
{
    /*
     * LDR Xt, [Xn, #imm]
     */
    if ((insn & 0xFFC00000u) != 0xF9400000u)
        return NO;

    if (rt)
        *rt = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (imm12)
        *imm12 = (insn >> 10) & 0xFFFu;

    return YES;
}


bool pxQoLIsLDR64Register(uint32_t insn,
                               uint32_t *rt,
                               uint32_t *rn,
                               uint32_t *rm)
{
    /*
     * LDR Xt, [Xn, Xm]
     */
    if ((insn & 0xFFE00C00u) != 0xF8600800u)
        return NO;

    if (rt)
        *rt = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (rm)
        *rm = (insn >> 16) & 0x1Fu;

    return YES;
}


bool pxQoLIsSTR64Register(uint32_t insn,
                               uint32_t *rt,
                               uint32_t *rn,
                               uint32_t *rm)
{
    /*
     * STR Xt, [Xn, Xm]
     */
    if ((insn & 0xFFE00C00u) != 0xF8200800u)
        return NO;

    if (rt)
        *rt = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (rm)
        *rm = (insn >> 16) & 0x1Fu;

    return YES;
}


bool pxQoLIsBL(uint32_t insn)
{
    return (insn & 0xFC000000u) == 0x94000000u;
}


bool pxQoLIsB(uint32_t insn)
{
    return (insn & 0xFC000000u) == 0x14000000u;
}


bool pxQoLDecodeADD64RegisterNoShift(uint32_t insn,
                                          uint32_t *rd,
                                          uint32_t *rn,
                                          uint32_t *rm)
{
    /*
     * ADD Xd, Xn, Xm
     *
     * 64-bit, no flags, LSL #0.
     */
    if ((insn & 0xFFE0FC00u) != 0x8B000000u)
        return NO;

    if (rd)
        *rd = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (rm)
        *rm = (insn >> 16) & 0x1Fu;

    return YES;
}


bool pxQoLDecodeADD64ImmediateNoShift(uint32_t insn,
                                           uint32_t *rd,
                                           uint32_t *rn,
                                           uint32_t *imm12)
{
    /*
     * ADD Xd, Xn, #imm12
     *
     * 64-bit, no flags, shift = 0.
     */
    if ((insn & 0xFFC00000u) != 0x91000000u)
        return NO;

    if (rd)
        *rd = insn & 0x1Fu;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    if (imm12)
        *imm12 = (insn >> 10) & 0xFFFu;

    return YES;
}


bool pxQoLDecodeMovReg(uint32_t insn,
                            uint32_t *dstReg,
                            uint32_t *srcReg)
{
    /*
     * MOV Xd, Xn
     *
     * Actual encoding:
     *   ORR Xd, XZR, Xn
     */
    if ((insn & 0xFFE0FFE0u) != 0xAA0003E0u)
        return NO;

    if (dstReg)
        *dstReg = insn & 0x1Fu;

    if (srcReg)
        *srcReg = (insn >> 16) & 0x1Fu;

    return YES;
}


bool pxQoLIsMovReg(uint32_t insn,
                        uint32_t dstReg,
                        uint32_t srcReg)
{
    uint32_t decodedDst = 0;
    uint32_t decodedSrc = 0;

    if (!pxQoLDecodeMovReg(
            insn,
            &decodedDst,
            &decodedSrc))
        return NO;

    return
        decodedDst == dstReg &&
        decodedSrc == srcReg;
}


bool pxQoLDecodeLDUR64(uint32_t insn,
                            uint32_t *rt,
                            uint32_t *rn,
                            int32_t *imm9)
{
    /*
     * LDUR Xt, [Xn, #simm9]
     */
    if ((insn & 0xFFE00C00u) != 0xF8400000u)
        return NO;

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

    return YES;
}


bool pxQoLDecodeBLR(uint32_t insn,
                         uint32_t *rn)
{
    /*
     * BLR Xn
     */
    if ((insn & 0xFFFFFC1Fu) != 0xD63F0000u)
        return NO;

    if (rn)
        *rn = (insn >> 5) & 0x1Fu;

    return YES;
}


bool pxQoLDecodeADRP(uint32_t insn,
                          uintptr_t pc,
                          uint32_t *rd,
                          uintptr_t *target)
{
    if (!pxQoLIsADRP(insn, rd))
        return NO;

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

    return YES;
}


bool pxQoLReadU32(uintptr_t address,
                       uint32_t *value)
{
    vm_size_t outSize = 0;

    kern_return_t kr =
        vm_read_overwrite(
            mach_task_self(),
            (vm_address_t)address,
            sizeof(uint32_t),
            (vm_address_t)value,
            &outSize
        );

    if (kr != KERN_SUCCESS)
        return NO;

    return outSize == sizeof(uint32_t);
}


bool pxQoLReadU64(uintptr_t address,
                       uint64_t *value)
{
    vm_size_t outSize = 0;

    kern_return_t kr =
        vm_read_overwrite(
            mach_task_self(),
            (vm_address_t)address,
            sizeof(uint64_t),
            (vm_address_t)value,
            &outSize
        );

    if (kr != KERN_SUCCESS)
        return NO;

    return outSize == sizeof(uint64_t);
}


bool pxQoLDecodeBLTarget(uint32_t insn,
                              uintptr_t pc,
                              uintptr_t *target)
{
    if (!pxQoLIsBL(insn))
        return NO;

    int64_t imm26 =
        (int64_t)(insn & 0x03FFFFFFu);

    if (imm26 & 0x02000000)
        imm26 |= ~0x03FFFFFFLL;

    intptr_t delta =
        (intptr_t)(imm26 << 2);

    if (target)
        *target = pc + delta;

    return YES;
}


bool pxQoLDecodeBranchTarget(uint32_t insn,
                                  uintptr_t pc,
                                  uintptr_t *target)
{
    if (!pxQoLIsB(insn))
        return NO;

    int64_t imm26 =
        (int64_t)(insn & 0x03FFFFFFu);

    if (imm26 & 0x02000000)
        imm26 |= ~0x03FFFFFFLL;

    intptr_t delta =
        (intptr_t)(imm26 << 2);

    if (target)
        *target = pc + delta;

    return YES;
}


bool pxQoLMakeB(uintptr_t source,
                     uintptr_t target,
                     uint32_t *instruction)
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
        return NO;

    if (delta < -(1LL << 27) ||
        delta >  ((1LL << 27) - 4))
        return NO;

    int64_t imm26 =
        ((int64_t)delta) >> 2;

    *instruction =
        0x14000000u |
        ((uint32_t)imm26 & 0x03FFFFFFu);

    return YES;
}


bool pxQoLMakeBL(uintptr_t source,
                      uintptr_t target,
                      uint32_t *instruction)
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
        return NO;

    if (delta < -(1LL << 27) ||
        delta >  ((1LL << 27) - 4))
        return NO;

    int64_t imm26 =
        ((int64_t)delta) >> 2;

    *instruction =
        0x94000000u |
        ((uint32_t)imm26 & 0x03FFFFFFu);

    return YES;
}


bool pxQoLMakeMOVZ32(uint32_t rd,
                          uint16_t imm16,
                          uint32_t *instruction)
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
        return NO;

    *instruction =
        0x52800000u |
        ((uint32_t)imm16 << 5) |
        rd;

    return YES;
}
