#ifndef PXQOL_LEGACY_ADCONTAININGVIEWCONTROLLER_FINDER_H
#define PXQOL_LEGACY_ADCONTAININGVIEWCONTROLLER_FINDER_H

#import <Foundation/Foundation.h>

#include <stdint.h>

typedef struct {
    uint8_t *match;

    int variant;

    uintptr_t branchTarget;

    uintptr_t globalAddress;
    uint64_t globalValue;

    uint32_t objectReg;
    uint32_t indexReg;
    uint32_t loadedReg;
    uint32_t storedReg;
} pxQoLAdContainingViewControllerMatch;

BOOL pxQoLFindAdContainingViewControllerMatch(
    uint8_t *text,
    unsigned long textSize,
    uint64_t targetIvarOffset,
    pxQoLAdContainingViewControllerMatch *result
);

#endif