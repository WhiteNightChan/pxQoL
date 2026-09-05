#ifndef pxQoLARM64_h
#define pxQoLARM64_h

#include <stdint.h>
#include <stdbool.h>


bool pxQoLIsADRP(
    uint32_t insn,
    uint32_t *rd
);

bool pxQoLIsLDR64UnsignedImm(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *imm12
);

bool pxQoLIsLDR64Register(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *rm
);

bool pxQoLIsSTR64Register(
    uint32_t insn,
    uint32_t *rt,
    uint32_t *rn,
    uint32_t *rm
);

bool pxQoLIsBL(
    uint32_t insn
);

bool pxQoLIsB(
    uint32_t insn
);

bool pxQoLIsMovReg(
    uint32_t insn,
    uint32_t dstReg,
    uint32_t srcReg
);

bool pxQoLDecodeADRP(
    uint32_t insn,
    uintptr_t pc,
    uint32_t *rd,
    uintptr_t *target
);

bool pxQoLReadU64(
    uintptr_t address,
    uint64_t *value
);

bool pxQoLDecodeBranchTarget(
    uint32_t insn,
    uintptr_t pc,
    uintptr_t *target
);

bool pxQoLMakeB(
    uintptr_t source,
    uintptr_t target,
    uint32_t *instruction
);

#endif