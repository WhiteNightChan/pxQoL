#import "Metadata.h"
#import "../Core/MemoryAccess.h"

#include <string.h>


bool pxqSwiftMetadataReadStructDescriptorInfo(
    uintptr_t descriptor,
    PXQSwiftStructDescriptorInfo *header
)
{
    if (descriptor == 0 ||
        !header) {

        return false;
    }

    uint32_t rawNameRelative = 0;
    uint32_t rawAccessorRelative = 0;
    uint32_t rawFieldsRelative = 0;

    header->nameFieldAddress =
        descriptor + 0x08;

    header->metadataAccessorFieldAddress =
        descriptor + 0x0C;

    header->fieldsFieldAddress =
        descriptor + 0x10;

    if (!pxqMemoryReadU32(
            descriptor + 0x00,
            &header->flags) ||

        !pxqMemoryReadU32(
            header->nameFieldAddress,
            &rawNameRelative) ||

        !pxqMemoryReadU32(
            header->metadataAccessorFieldAddress,
            &rawAccessorRelative) ||

        !pxqMemoryReadU32(
            header->fieldsFieldAddress,
            &rawFieldsRelative) ||

        !pxqMemoryReadU32(
            descriptor + 0x14,
            &header->numFields) ||

        !pxqMemoryReadU32(
            descriptor + 0x18,
            &header->fieldOffsetVectorOffset)) {

        return false;
    }

    header->nameRelativeOffset =
        (int32_t)rawNameRelative;

    header->metadataAccessorRelativeOffset =
        (int32_t)rawAccessorRelative;

    header->fieldsRelativeOffset =
        (int32_t)rawFieldsRelative;

    return true;
}


bool pxqSwiftMetadataResolveRelativePointer(
    uintptr_t relativePointerField,
    int32_t relativeOffset,
    uintptr_t *target
)
{
    return pxqAddressResolveRelative32(
        relativePointerField,
        relativeOffset,
        target
    );
}


bool pxqSwiftMetadataReadFieldDescriptorInfo(
    uintptr_t fieldDescriptor,
    PXQSwiftFieldDescriptorInfo *header
)
{
    if (fieldDescriptor == 0 ||
        !header) {

        return false;
    }

    uint32_t rawHeader = 0;

    if (!pxqMemoryReadU32(
            fieldDescriptor + 0x08,
            &rawHeader) ||

        !pxqMemoryReadU32(
            fieldDescriptor + 0x0C,
            &header->numFields)) {

        return false;
    }

    header->recordSize =
        rawHeader >> 16;

    return true;
}


bool pxqSwiftMetadataResolveFieldRecord(
    uintptr_t fieldDescriptor,
    uint32_t recordIndex,
    uint32_t recordSize,
    uintptr_t *record
)
{
    if (fieldDescriptor == 0 ||
        !record) {

        return false;
    }

    uint64_t recordOffset =
        0x10ull +
        (uint64_t)recordIndex *
        (uint64_t)recordSize;

    if (recordOffset >
        (uint64_t)UINTPTR_MAX -
        (uint64_t)fieldDescriptor) {

        return false;
    }

    *record =
        fieldDescriptor +
        (uintptr_t)recordOffset;

    return true;
}


bool pxqSwiftMetadataReadFieldRecordName(
    uintptr_t fieldRecord,
    char *buffer,
    size_t capacity
)
{
    if (fieldRecord == 0)
        return false;

    return pxqSwiftMetadataReadRelativeCString(
        fieldRecord + 0x08,
        buffer,
        capacity
    );
}


bool pxqSwiftMetadataReadRelativeCString(
    uintptr_t relativePointerField,
    char *buffer,
    size_t capacity
)
{
    if (relativePointerField == 0 ||
        !buffer ||
        capacity == 0) {

        return false;
    }

    uint32_t rawRelativeOffset = 0;

    if (!pxqMemoryReadU32(
            relativePointerField,
            &rawRelativeOffset) ||

        rawRelativeOffset == 0) {

        return false;
    }

    uintptr_t stringAddress = 0;

    if (!pxqSwiftMetadataResolveRelativePointer(
            relativePointerField,
            (int32_t)rawRelativeOffset,
            &stringAddress)) {

        return false;
    }

    return pxqMemoryReadCString(
        stringAddress,
        buffer,
        capacity
    );
}


bool pxqSwiftMetadataResolveUnresolvedOptionalNominalTypeReference(
    uintptr_t typeReference,
    uintptr_t *nominalTypeDescriptor
)
{
    if (typeReference == 0 ||
        !nominalTypeDescriptor) {

        return false;
    }

    uint64_t raw = 0;

    if (!pxqMemoryReadU64(
            typeReference,
            &raw)) {

        return false;
    }

    /*
     * Proven unresolved Swift lazy type-reference cell form:
     *
     *   low32  = signed relative pointer from the cell to the mangling
     *   high32 = negative mangling length
     *
     * Once resolved, bit63 clears and the cell becomes metadata. The
     * resolved form is intentionally not interpreted here.
     */
    if ((raw &
         0x8000000000000000ull) == 0) {

        return false;
    }

    int32_t mangledRelative =
        (int32_t)(
            raw &
            0xFFFFFFFFu
        );

    int32_t encodedLength =
        (int32_t)(
            raw >>
            32
        );

    if (encodedLength >= 0)
        return false;

    int64_t mangledLength =
        -(int64_t)encodedLength;

    /*
     * Proven symbolic representation for Optional<NominalType>:
     *
     *   0x02 <rel32 indirect Context> 'S' 'g'
     */
    if (mangledLength != 7)
        return false;

    uintptr_t mangled = 0;

    if (!pxqSwiftMetadataResolveRelativePointer(
            typeReference,
            mangledRelative,
            &mangled)) {

        return false;
    }

    uint8_t bytes[7];

    if (!pxqMemoryRead(
            mangled,
            bytes,
            sizeof(bytes)) ||

        bytes[0] != 0x02 ||
        bytes[5] != (uint8_t)'S' ||
        bytes[6] != (uint8_t)'g') {

        return false;
    }

    int32_t descriptorSlotRelative = 0;

    memcpy(
        &descriptorSlotRelative,
        &bytes[1],
        sizeof(descriptorSlotRelative)
    );

    uintptr_t descriptorSlot = 0;

    if (!pxqSwiftMetadataResolveRelativePointer(
            mangled + 1,
            descriptorSlotRelative,
            &descriptorSlot)) {

        return false;
    }

    uint64_t descriptorRaw = 0;

    if (!pxqMemoryReadU64(
            descriptorSlot,
            &descriptorRaw) ||

        descriptorRaw == 0) {

        return false;
    }

    *nominalTypeDescriptor =
        (uintptr_t)descriptorRaw;

    return true;
}


bool pxqSwiftRuntimeReadStructMetadataInfo(
    const void *metadata,
    PXQSwiftRuntimeStructMetadataInfo *info
)
{
    if (!metadata ||
        !info) {

        return false;
    }

    const uint8_t *metadataBytes =
        (const uint8_t *)metadata;

    const uint8_t *descriptor =
        *(const uint8_t * const *)(
            metadataBytes +
            0x08
        );

    if (!descriptor)
        return false;

    const uint8_t *nameField =
        descriptor +
        0x08;

    int32_t nameRelative =
        *(const int32_t *)nameField;

    if (nameRelative == 0)
        return false;

    const char *typeName =
        (const char *)(
            nameField +
            nameRelative
        );

    const uint8_t *fieldsField =
        descriptor +
        0x10;

    int32_t fieldsRelative =
        *(const int32_t *)fieldsField;

    if (fieldsRelative == 0)
        return false;

    info->typeName =
        typeName;

    info->fields =
        fieldsField +
        fieldsRelative;

    info->numFields =
        *(const uint32_t *)(
            descriptor +
            0x14
        );

    info->fieldOffsetVectorOffset =
        *(const uint32_t *)(
            descriptor +
            0x18
        );

    return true;
}


bool pxqSwiftRuntimeReadFieldDescriptorInfo(
    const uint8_t *fieldDescriptor,
    PXQSwiftRuntimeFieldDescriptorInfo *info
)
{
    if (!fieldDescriptor ||
        !info) {

        return false;
    }

    info->recordSize =
        *(const uint16_t *)(
            fieldDescriptor +
            0x0A
        );

    info->numFields =
        *(const uint32_t *)(
            fieldDescriptor +
            0x0C
        );

    return true;
}


const char *pxqSwiftRuntimeFieldRecordName(
    const uint8_t *fieldDescriptor,
    uint16_t recordSize,
    uint32_t recordIndex
)
{
    if (!fieldDescriptor)
        return NULL;

    const uint8_t *record =
        fieldDescriptor +
        0x10 +
        ((size_t)recordIndex *
         (size_t)recordSize);

    const uint8_t *fieldNameField =
        record +
        0x08;

    int32_t fieldNameRelative =
        *(const int32_t *)fieldNameField;

    if (fieldNameRelative == 0)
        return NULL;

    return (const char *)(
        fieldNameField +
        fieldNameRelative
    );
}


bool pxqSwiftRuntimeReadFieldOffset(
    const void *metadata,
    uint32_t fieldOffsetVectorOffset,
    uint32_t fieldIndex,
    int32_t *fieldOffset
)
{
    if (!metadata ||
        !fieldOffset) {

        return false;
    }

    const uint8_t *metadataBytes =
        (const uint8_t *)metadata;

    size_t fieldOffsetVectorStart =
        (size_t)fieldOffsetVectorOffset *
        sizeof(uintptr_t);

    size_t fieldSlotOffset =
        fieldOffsetVectorStart +
        ((size_t)fieldIndex *
         sizeof(uint32_t));

    *fieldOffset =
        *(const int32_t *)(
            metadataBytes +
            fieldSlotOffset
        );

    return true;
}
