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


bool pxQoLIsMovReg(uint32_t insn,
                        uint32_t dstReg,
                        uint32_t srcReg)
{
    /*
     * MOV Xd, Xn
     *
     * Actual encoding:
     *   ORR Xd, XZR, Xn
     */
    if ((insn & 0xFFE0FFE0u) != 0xAA0003E0u)
        return NO;

    uint32_t rm = (insn >> 16) & 0x1Fu;
    uint32_t rn = (insn >> 5) & 0x1Fu;
    uint32_t rd = insn & 0x1Fu;

    if (rn != 31)
        return NO;

    return rd == dstReg && rm == srcReg;
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
     * range = +/- 128 MB
     */
    if ((delta & 0x3) != 0)
        return NO;

    if (delta < -(0x20000000LL) ||
        delta >  (0x1FFFFFFLL << 2))
        return NO;

    int64_t imm26 =
        ((int64_t)delta) >> 2;

    *instruction =
        0x14000000u |
        ((uint32_t)imm26 & 0x03FFFFFFu);

    return YES;
}