#ifndef PXQ_BINARY_PATCH_SWIFT_ABI_VALUE_WITNESS_H
#define PXQ_BINARY_PATCH_SWIFT_ABI_VALUE_WITNESS_H

#include <stdbool.h>
#include <stdint.h>

#define PXQ_SWIFT_VALUE_WITNESS_TABLE_METADATA_RELATIVE_OFFSET (-(int32_t)sizeof(uintptr_t))
#define PXQ_SWIFT_VALUE_WITNESS_ASSIGN_WITH_COPY_POINTER_INDEX 3u
#define PXQ_SWIFT_VALUE_WITNESS_ASSIGN_WITH_TAKE_POINTER_INDEX 5u
#define PXQ_SWIFT_VALUE_WITNESS_GET_ENUM_TAG_SINGLE_PAYLOAD_POINTER_INDEX 6u


typedef uint32_t (*PXQSwiftGetEnumTagSinglePayloadFunction)(
    const void *value,
    uint32_t emptyCases,
    const void *metadata
);


/*
 * Runtime-only direct metadata access. Static candidate analysis keeps using
 * safe process-memory reads and the slot constants above.
 */
bool pxqSwiftRuntimeGetEnumTagSinglePayloadFunction(
    const void *metadata,
    PXQSwiftGetEnumTagSinglePayloadFunction *function
);

#endif
