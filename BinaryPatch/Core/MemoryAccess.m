#import "MemoryAccess.h"

#import <mach/mach.h>

static bool pxqMemoryReadRaw(
    uintptr_t address,
    void *buffer,
    size_t size
)
{
    vm_size_t outSize = 0;

    kern_return_t kr =
        vm_read_overwrite(
            mach_task_self(),
            (vm_address_t)address,
            (vm_size_t)size,
            (vm_address_t)buffer,
            &outSize
        );

    return
        kr == KERN_SUCCESS &&
        outSize == (vm_size_t)size;
}


bool pxqMemoryRead(
    uintptr_t address,
    void *buffer,
    size_t size
)
{
    if (address == 0 ||
        !buffer ||
        size == 0) {

        return false;
    }

    return pxqMemoryReadRaw(
        address,
        buffer,
        size
    );
}


bool pxqMemoryReadU32(
    uintptr_t address,
    uint32_t *value
)
{
    return pxqMemoryReadRaw(
        address,
        value,
        sizeof(uint32_t)
    );
}


bool pxqMemoryReadU64(
    uintptr_t address,
    uint64_t *value
)
{
    return pxqMemoryReadRaw(
        address,
        value,
        sizeof(uint64_t)
    );
}


bool pxqMemoryReadCString(
    uintptr_t address,
    char *buffer,
    size_t capacity
)
{
    if (address == 0 ||
        !buffer ||
        capacity < 2) {

        return false;
    }

    for (size_t i = 0;
         i < capacity;
         i++) {

        uint8_t value = 0;

        if (i >
            (size_t)(UINTPTR_MAX - address)) {

            return false;
        }

        if (!pxqMemoryRead(
                address + i,
                &value,
                sizeof(value))) {

            return false;
        }

        buffer[i] =
            (char)value;

        if (value == 0)
            return true;
    }

    buffer[
        capacity - 1
    ] = '\0';

    return false;
}


bool pxqAddressAddSignedOffset(
    uintptr_t base,
    int64_t offset,
    uintptr_t *result
)
{
    if (!result)
        return false;

    if (offset >= 0) {

        uint64_t positive =
            (uint64_t)offset;

        if (positive >
            (uint64_t)UINTPTR_MAX -
            (uint64_t)base) {

            return false;
        }

        *result =
            base +
            (uintptr_t)positive;

        return true;
    }

    uint64_t magnitude =
        (uint64_t)(-(offset + 1)) +
        1u;

    if ((uint64_t)base <
        magnitude) {

        return false;
    }

    *result =
        base -
        (uintptr_t)magnitude;

    return true;
}


bool pxqAddressResolveRelative32(
    uintptr_t base,
    int32_t relativeOffset,
    uintptr_t *result
)
{
    return pxqAddressAddSignedOffset(
        base,
        (int64_t)relativeOffset,
        result
    );
}


bool pxqAddressRangeContains(
    uintptr_t rangeStart,
    size_t rangeSize,
    uintptr_t address,
    size_t size
)
{
    if (address < rangeStart)
        return false;

    uintptr_t offset =
        address - rangeStart;

    if (offset > (uintptr_t)rangeSize)
        return false;

    return size <=
        rangeSize -
        (size_t)offset;
}
