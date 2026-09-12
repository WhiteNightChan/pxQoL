#import "Semantics.h"
#import "../../SwiftABI/Metadata.h"
#import "../../Core/MemoryAccess.h"

#include <string.h>


static const char * const
    kPXQPixivOAuthUserTypeName =
        "PixivOAuthUser";

static const char * const
    kPXQPixivOAuthUserPremiumFieldName =
        "isPremium";


bool pxqValidatePixivOAuthUserTypeDescriptor(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t descriptor,
    PXQPixivOAuthUserTypeDescriptorEvidence *evidence
)
{
    if (!text ||
        textSize == 0 ||
        descriptor == 0 ||
        !evidence) {

        return false;
    }

    PXQSwiftStructDescriptorInfo descriptorInfo;

    if (!pxqSwiftMetadataReadStructDescriptorInfo(
            descriptor,
            &descriptorInfo)) {

        return false;
    }

    if ((descriptorInfo.flags &
         PXQ_SWIFT_CONTEXT_DESCRIPTOR_KIND_MASK) !=
            PXQ_SWIFT_CONTEXT_DESCRIPTOR_KIND_STRUCT ||

        descriptorInfo.nameRelativeOffset == 0 ||
        descriptorInfo.metadataAccessorRelativeOffset == 0 ||
        descriptorInfo.fieldsRelativeOffset == 0 ||

        descriptorInfo.numFields == 0 ||
        descriptorInfo.numFields > 64) {

        return false;
    }

    uintptr_t nameAddress = 0;
    uintptr_t metadataAccessor = 0;
    uintptr_t fields = 0;

    if (!pxqSwiftMetadataResolveRelativePointer(
            descriptorInfo.nameFieldAddress,
            descriptorInfo.nameRelativeOffset,
            &nameAddress) ||

        !pxqSwiftMetadataResolveRelativePointer(
            descriptorInfo.metadataAccessorFieldAddress,
            descriptorInfo.metadataAccessorRelativeOffset,
            &metadataAccessor) ||

        !pxqSwiftMetadataResolveRelativePointer(
            descriptorInfo.fieldsFieldAddress,
            descriptorInfo.fieldsRelativeOffset,
            &fields)) {

        return false;
    }

    char typeName[64];

    if (!pxqMemoryReadCString(
            nameAddress,
            typeName,
            sizeof(typeName)) ||

        strcmp(
            typeName,
            kPXQPixivOAuthUserTypeName) != 0) {

        return false;
    }

    if (!pxqAddressRangeContains(
            (uintptr_t)text,
            (size_t)textSize,
            metadataAccessor,
            sizeof(uint32_t))) {

        return false;
    }

    PXQSwiftFieldDescriptorInfo fieldDescriptorInfo;

    if (!pxqSwiftMetadataReadFieldDescriptorInfo(
            fields,
            &fieldDescriptorInfo)) {

        return false;
    }

    if (fieldDescriptorInfo.recordSize < 12 ||
        fieldDescriptorInfo.recordSize > 0x100 ||
        fieldDescriptorInfo.numFields !=
            descriptorInfo.numFields) {

        return false;
    }

    size_t premiumFieldCount = 0;

    for (uint32_t i = 0;
         i < fieldDescriptorInfo.numFields;
         i++) {

        uintptr_t record = 0;

        if (!pxqSwiftMetadataResolveFieldRecord(
                fields,
                i,
                fieldDescriptorInfo.recordSize,
                &record)) {

            return false;
        }

        char fieldName[128];

        if (!pxqSwiftMetadataReadFieldRecordName(
                record,
                fieldName,
                sizeof(fieldName))) {

            return false;
        }

        if (strcmp(
                fieldName,
                kPXQPixivOAuthUserPremiumFieldName) == 0) {

            premiumFieldCount++;
        }
    }

    if (premiumFieldCount != 1)
        return false;

    evidence->pixivOAuthUserMetadataAccessor =
        metadataAccessor;

    evidence->fieldCount =
        descriptorInfo.numFields;

    evidence->fieldOffsetVectorOffset =
        descriptorInfo.fieldOffsetVectorOffset;

    return true;
}


bool pxqResolvePixivOAuthUserPremiumStorageOffset(
    const void *metadata,
    int32_t *storageOffset
)
{
    if (!metadata ||
        !storageOffset) {

        return false;
    }

    PXQSwiftRuntimeStructMetadataInfo metadataInfo;

    if (!pxqSwiftRuntimeReadStructMetadataInfo(
            metadata,
            &metadataInfo)) {

        return false;
    }

    if (!metadataInfo.typeName ||
        strcmp(
            metadataInfo.typeName,
            kPXQPixivOAuthUserTypeName) != 0) {

        return false;
    }

    if (metadataInfo.numFields == 0 ||
        metadataInfo.numFields > 64 ||
        metadataInfo.fieldOffsetVectorOffset == 0 ||
        metadataInfo.fieldOffsetVectorOffset > 0x100) {

        return false;
    }

    PXQSwiftRuntimeFieldDescriptorInfo fieldDescriptorInfo;

    if (!pxqSwiftRuntimeReadFieldDescriptorInfo(
            metadataInfo.fields,
            &fieldDescriptorInfo)) {

        return false;
    }

    if (fieldDescriptorInfo.recordSize < 12 ||
        fieldDescriptorInfo.recordSize > 64 ||
        fieldDescriptorInfo.numFields !=
            metadataInfo.numFields) {

        return false;
    }

    size_t premiumFieldCount = 0;
    uint32_t premiumFieldIndex = 0;

    for (uint32_t i = 0;
         i < fieldDescriptorInfo.numFields;
         i++) {

        const char *fieldName =
            pxqSwiftRuntimeFieldRecordName(
                metadataInfo.fields,
                fieldDescriptorInfo.recordSize,
                i
            );

        if (fieldName &&
            strcmp(
                fieldName,
                kPXQPixivOAuthUserPremiumFieldName) == 0) {

            premiumFieldCount++;
            premiumFieldIndex =
                i;
        }
    }

    if (premiumFieldCount != 1)
        return false;

    int32_t objectOffset = 0;

    if (!pxqSwiftRuntimeReadFieldOffset(
            metadata,
            metadataInfo.fieldOffsetVectorOffset,
            premiumFieldIndex,
            &objectOffset)) {

        return false;
    }

    if (objectOffset < 0 ||
        objectOffset > 0x1000) {

        return false;
    }

    *storageOffset =
        objectOffset;

    return true;
}
