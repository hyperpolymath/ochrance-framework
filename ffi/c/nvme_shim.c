// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

/// nvme_shim.c — Thin C shim for NVMe device access.
///
/// Minimal wrappers around Linux NVMe ioctls. This file is intentionally
/// small (~50 lines of logic); all complex verification lives in Idris2.
///
/// Build: cc -c -o nvme_shim.o nvme_shim.c
/// Link:  ar rcs libochrance_nvme.a nvme_shim.o

#include "nvme_shim.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/nvme_ioctl.h>

/// Internal: open an NVMe device, returning fd or negative errno.
static int open_nvme(const char *device_path) {
    if (!device_path) return -EINVAL;
    int fd = open(device_path, O_RDONLY);
    if (fd < 0) return -errno;
    return fd;
}

int ochrance_nvme_read_smart(const char *device_path,
                             ochrance_smart_info_t *info) {
    if (!info) return -EINVAL;

    int fd = open_nvme(device_path);
    if (fd < 0) return fd;

    // NVMe Admin Command: Get Log Page (SMART/Health, Log ID 0x02)
    struct nvme_admin_cmd cmd;
    memset(&cmd, 0, sizeof(cmd));
    cmd.opcode  = 0x02;             // Get Log Page
    cmd.nsid    = 0xFFFFFFFF;       // All namespaces
    cmd.addr    = (uint64_t)(uintptr_t)info;
    cmd.data_len = sizeof(*info);
    cmd.cdw10   = 0x02 | (((sizeof(*info) / 4) - 1) << 16); // Log ID + NUMD

    int ret = ioctl(fd, NVME_IOCTL_ADMIN_CMD, &cmd);
    close(fd);

    return (ret < 0) ? -errno : 0;
}

int ochrance_nvme_read_block(const char *device_path,
                             uint64_t lba,
                             void *buffer,
                             size_t block_size) {
    if (!buffer || block_size == 0) return -EINVAL;

    int fd = open(device_path, O_RDONLY);
    if (fd < 0) return -errno;

    off_t offset = (off_t)(lba * block_size);
    ssize_t n = pread(fd, buffer, block_size, offset);
    close(fd);

    if (n < 0) return -errno;
    if ((size_t)n != block_size) return -EIO;
    return 0;
}

int ochrance_nvme_write_block(const char *device_path,
                              uint64_t lba,
                              const void *buffer,
                              size_t block_size) {
    if (!buffer || block_size == 0) return -EINVAL;

    int fd = open(device_path, O_WRONLY);
    if (fd < 0) return -errno;

    off_t offset = (off_t)(lba * block_size);
    ssize_t n = pwrite(fd, buffer, block_size, offset);
    close(fd);

    if (n < 0) return -errno;
    if ((size_t)n != block_size) return -EIO;
    return 0;
}
