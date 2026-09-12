#ifndef PXQ_BINARY_PATCH_SWIFT_ABI_METADATA_H
#define PXQ_BINARY_PATCH_SWIFT_ABI_METADATA_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define PXQ_SWIFT_CONTEXT_DESCRIPTOR_KIND_MASK 0x1Fu
#define PXQ_SWIFT_CONTEXT_DESCRIPTOR_KIND_STRUCT 17u


typedef void *(*PXQSwiftMetadataAccessorFunction)(
    uintptr_t request
);


typedef struct {
    uint32_t flags;
    uintptr_t nameFieldAddress;
    uintptr_t metadataAccessorFieldAddress;
    uintptr_t fieldsFieldAddress;
    int32_t nameRelativeOffset;
    int32_t metadataAccessorRelativeOffset;
    int32_t fieldsRelativeOffset;
    uint32_t numFields;
    uint32_t fieldOffsetVectorOffset;
} PXQSwiftStructDescriptorInfo;


typedef struct {
    uint32_t recordSize;
    uint32_t numFields;
} PXQSwiftFieldDescriptorInfo;


typedef struct {
    const char *typeName;
    const uint8_t *fields;
    uint32_t numFields;
    uint32_t fieldOffsetVectorOffset;
} PXQSwiftRuntimeStructMetadataInfo;


typedef struct {
    uint16_t recordSize;
    uint32_t numFields;
} PXQSwiftRuntimeFieldDescriptorInfo;


/*
 * Static discovery APIs below read candidate data through Core/MemoryAccess.
 * Runtime APIs are intentionally separate and directly inspect metadata
 * supplied by the Swift runtime. Do not merge the two access models.
 */

bool pxqSwiftMetadataReadStructDescriptorInfo(
    uintptr_t descriptor,
    PXQSwiftStructDescriptorInfo *header
);

bool pxqSwiftMetadataResolveRelativePointer(
    uintptr_t relativePointerField,
    int32_t relativeOffset,
    uintptr_t *target
);

bool pxqSwiftMetadataReadFieldDescriptorInfo(
    uintptr_t fieldDescriptor,
    PXQSwiftFieldDescriptorInfo *header
);

bool pxqSwiftMetadataResolveFieldRecord(
    uintptr_t fieldDescriptor,
    uint32_t recordIndex,
    uint32_t recordSize,
    uintptr_t *record
);

bool pxqSwiftMetadataReadFieldRecordName(
    uintptr_t fieldRecord,
    char *buffer,
    size_t capacity
);

bool pxqSwiftMetadataReadRelativeCString(
    uintptr_t relativePointerField,
    char *buffer,
    size_t capacity
);

bool pxqSwiftMetadataResolveUnresolvedOptionalNominalTypeReference(
    uintptr_t typeReference,
    uintptr_t *nominalTypeDescriptor
);

bool pxqSwiftRuntimeReadStructMetadataInfo(
    const void *metadata,
    PXQSwiftRuntimeStructMetadataInfo *info
);

bool pxqSwiftRuntimeReadFieldDescriptorInfo(
    const uint8_t *fieldDescriptor,
    PXQSwiftRuntimeFieldDescriptorInfo *info
);

const char *pxqSwiftRuntimeFieldRecordName(
    const uint8_t *fieldDescriptor,
    uint16_t recordSize,
    uint32_t recordIndex
);

bool pxqSwiftRuntimeReadFieldOffset(
    const void *metadata,
    uint32_t fieldOffsetVectorOffset,
    uint32_t fieldIndex,
    int32_t *fieldOffset
);

#endif
