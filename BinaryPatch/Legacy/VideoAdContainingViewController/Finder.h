#ifndef PXQOL_LEGACY_VIDEOADCONTAININGVIEWCONTROLLER_FINDER_H
#define PXQOL_LEGACY_VIDEOADCONTAININGVIEWCONTROLLER_FINDER_H

#import <Foundation/Foundation.h>

#include <stdint.h>

typedef struct {
    // ADRP x8, ... の位置
    uint8_t *patch1;

    // MOV x0, x20 の位置
    uint8_t *patch2;

    // patch1 + 4 から分岐する先
    uintptr_t branchTarget;

    // ADRP + LDR で解決したglobal
    uintptr_t globalAddress;
    uint64_t globalValue;

    // containedViewControllerへのアクセスに使用されるレジスタ
    uint32_t objectReg;
    uint32_t indexReg;
    uint32_t loadedReg;
    uint32_t storedReg;

} pxQoLVideoAdContainingViewControllerMatch;

BOOL pxQoLFindVideoAdContainingViewControllerMatch(
    uint8_t *text,
    unsigned long textSize,
    uint64_t targetIvarOffset,
    pxQoLVideoAdContainingViewControllerMatch *result
);

#endif