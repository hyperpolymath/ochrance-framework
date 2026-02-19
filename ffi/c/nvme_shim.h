// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

/// nvme_shim.h — Thin C shim for NVMe device access.
///
/// Provides minimal wrappers around Linux NVMe ioctls for use by the
/// Ochrance framework's Idris2 FFI layer. These functions handle raw
/// block I/O and SMART health data retrieval.
///
/// All functions return 0 on success, negative errno on failure.
/// Buffer ownership: callers allocate and free all buffers.

#ifndef OCHRANCE_NVME_SHIM_H
#define OCHRANCE_NVME_SHIM_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// SMART health information structure.
/// Mirrors the NVMe SMART/Health Information Log (Log Identifier 02h).
typedef struct {
    uint8_t  critical_warning;       ///< Bitmask of critical warnings
    uint16_t composite_temperature;  ///< Composite temperature (Kelvin)
    uint8_t  available_spare;        ///< Available spare percentage
    uint8_t  available_spare_threshold; ///< Spare threshold percentage
    uint8_t  percentage_used;        ///< Percentage of rated endurance used
    uint64_t data_units_read;        ///< Data units read (in 512-byte units * 1000)
    uint64_t data_units_written;     ///< Data units written (in 512-byte units * 1000)
    uint64_t power_on_hours;         ///< Power-on hours
    uint32_t unsafe_shutdowns;       ///< Count of unsafe shutdowns
    uint32_t media_errors;           ///< Count of media and data integrity errors
} ochrance_smart_info_t;

/// Read NVMe SMART health information from a device.
///
/// @param device_path  Path to the NVMe device (e.g., "/dev/nvme0")
/// @param info         Output: SMART information structure
/// @return             0 on success, negative errno on failure
///                     -ENOENT if device does not exist
///                     -EACCES if insufficient permissions
///                     -EIO    if ioctl fails
int ochrance_nvme_read_smart(const char *device_path,
                             ochrance_smart_info_t *info);

/// Read a single block from an NVMe device.
///
/// @param device_path  Path to the NVMe block device (e.g., "/dev/nvme0n1")
/// @param lba          Logical block address to read
/// @param buffer       Output buffer (must be at least block_size bytes)
/// @param block_size   Size of a block in bytes (typically 4096)
/// @return             0 on success, negative errno on failure
///                     -EINVAL if buffer is NULL or block_size is 0
///                     -EIO    if read fails
int ochrance_nvme_read_block(const char *device_path,
                             uint64_t lba,
                             void *buffer,
                             size_t block_size);

/// Write a single block to an NVMe device.
///
/// @param device_path  Path to the NVMe block device (e.g., "/dev/nvme0n1")
/// @param lba          Logical block address to write
/// @param buffer       Input buffer containing block data
/// @param block_size   Size of a block in bytes (typically 4096)
/// @return             0 on success, negative errno on failure
///                     -EINVAL if buffer is NULL or block_size is 0
///                     -EIO    if write fails
///                     -EROFS  if device is read-only
int ochrance_nvme_write_block(const char *device_path,
                              uint64_t lba,
                              const void *buffer,
                              size_t block_size);

#ifdef __cplusplus
}
#endif

#endif // OCHRANCE_NVME_SHIM_H
