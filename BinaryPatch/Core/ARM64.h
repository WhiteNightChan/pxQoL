#ifndef PXQ_BINARY_PATCH_ARM64_H
#define PXQ_BINARY_PATCH_ARM64_H

#include <stdbool.h>
#include <stdint.h>

bool pxqARM64IsADRP(
    uint32_t insn,
    uint32_t *rd
);

bool pxqARM64IsLDR64UnsignedImmediate(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *imm12
);

bool pxqARM64IsLDR64Register(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *rm
);

bool pxqARM64IsSTR64Register(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *rm
);

bool pxqARM64IsBL(
    uint32_t insn
);

bool pxqARM64IsB(
    uint32_t insn
);

bool pxqARM64IsMoveRegister(
    uint32_t insn,
    uint32_t destinationRegister,
    uint32_t sourceRegister
);

bool pxqARM64DecodeADD64RegisterNoShift(
    uint32_t insn,
    uint32_t *rd,
    uint32_t *rn,
    uint32_t *rm
);

bool pxqARM64DecodeADD64ImmediateNoShift(
    uint32_t insn,
    uint32_t *rd,
    uint32_t *rn,
    uint32_t *imm12
);

bool pxqARM64DecodeMoveRegister(
    uint32_t insn,
    uint32_t *destinationRegister,
    uint32_t *sourceRegister
);

bool pxqARM64DecodeLDUR64(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    int32_t *imm9
);

bool pxqARM64DecodeBLR(
    uint32_t insn,
    uint32_t *rn
);

bool pxqARM64DecodeADRP(
    uint32_t insn,
    uintptr_t pc,
    uint32_t *rd,
    uintptr_t *target
);

bool pxqARM64DecodeBLTarget(
    uint32_t insn,
    uintptr_t pc,
    uintptr_t *target
);

bool pxqARM64DecodeBranchTarget(
    uint32_t insn,
    uintptr_t pc,
    uintptr_t *target
);

bool pxqARM64DecodeTBNZ(
    uint32_t insn,
    uintptr_t pc,
    uint32_t *rt,
    uint32_t *bitNumber,
    uintptr_t *target
);

bool pxqARM64EncodeB(
    uintptr_t source,
    uintptr_t target,
    uint32_t *instruction
);

bool pxqARM64EncodeBL(
    uintptr_t source,
    uintptr_t target,
    uint32_t *instruction
);

bool pxqARM64EncodeMOVZ32(
    uint32_t rd,
    uint16_t imm16,
    uint32_t *instruction
);

#endif
