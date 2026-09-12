#import "ValueWitness.h"

#include <stddef.h>


bool pxqSwiftRuntimeGetEnumTagSinglePayloadFunction(
    const void *metadata,
    PXQSwiftGetEnumTagSinglePayloadFunction *function
)
{
    if (!metadata ||
        !function) {

        return false;
    }

    const uint8_t *metadataBytes =
        (const uint8_t *)metadata;

    const uint8_t *valueWitnessTable =
        *(const uint8_t * const *)(
            metadataBytes +
            PXQ_SWIFT_VALUE_WITNESS_TABLE_METADATA_RELATIVE_OFFSET
        );

    if (!valueWitnessTable)
        return false;

    uintptr_t functionAddress =
        *(const uintptr_t *)(
            valueWitnessTable +
            ((size_t)
             PXQ_SWIFT_VALUE_WITNESS_GET_ENUM_TAG_SINGLE_PAYLOAD_POINTER_INDEX *
             sizeof(uintptr_t))
        );

    if (functionAddress == 0)
        return false;

    *function =
        (PXQSwiftGetEnumTagSinglePayloadFunction)
        functionAddress;

    return true;
}
