<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# FFI Contract: Idris2 + C Foreign Function Interface

> **Version:** 1.0.0-draft
> **Last updated:** 2026-02-19
> **Applies to:** Ochrance L1 (Block Observer) and L2 (Merkle Root) boundary

## 1. Overview

Ochrance uses Idris2 as its primary implementation language for all verification
logic (L2-L4). However, Idris2 cannot directly issue Linux `ioctl()` syscalls
or interact with the NVMe driver stack. Therefore, a thin C shim layer exists
at L1 to bridge Idris2 to the hardware.

**Direction of calls:** Idris2 calls C. Never the reverse.

```
  ┌──────────────────────────────────────────────┐
  │  L2: Idris2 (Merkle Root, Proofs, State)     │
  │                                              │
  │  verifyFilesystem : IO VerifiedState         │
  │       │                                      │
  │       │  %foreign "C:nvme_read_smart,ochrance_shim" │
  │       ▼                                      │
  ├──────────────────────────────────────────────┤
  │  L1: C shims (~200 lines total)              │
  │                                              │
  │  nvme_read_smart()                           │
  │  nvme_read_block()                           │
  │  nvme_write_block()                          │
  │                                              │
  │  Links: libnvme                              │
  └──────────────────────────────────────────────┘
            │
            ▼
  ┌──────────────────────────────────────────────┐
  │  L0: NVMe hardware (via Linux kernel driver) │
  └──────────────────────────────────────────────┘
```

## 2. Design Principles

### 2.1 C is "Too Dumb to Break Invariants"

The C shim layer is deliberately minimal and non-intelligent. It performs
exactly three operations:

1. Read NVMe SMART data (health/telemetry).
2. Read a block from a device.
3. Write a block to a device.

The C code does NOT:

- Validate block offsets (Idris2 dependent types enforce `offset < device_blocks`).
- Verify hash integrity (Idris2 computes and checks hashes).
- Manage state (Idris2 `VerifiedState` is the single source of truth).
- Retry failed I/O (Idris2 L3 handles retry/repair policy).
- Allocate heap memory (all buffers are caller-provided).

### 2.2 Idris2 Dependent Types as the Safety Net

Because C cannot express dependent types, the safety guarantees live
entirely in Idris2:

```idris
-- Idris2 enforces: offset must be strictly less than total block count.
-- This proof obligation is discharged at compile time.
readBlock : (dev : DeviceHandle)
         -> (offset : Fin (totalBlocks dev))
         -> IO (Either IOError Block)
readBlock dev offset = do
  let rawOffset = finToNat offset  -- safe: guaranteed < totalBlocks
  result <- primIO $ nvme_read_block_ffi (handleFd dev) (cast rawOffset)
  pure (parseResult result)
```

The `Fin (totalBlocks dev)` type ensures that `offset` is always within bounds.
There is no runtime bounds check in C because the Idris2 type system has
already proven it impossible to construct an out-of-bounds offset.

### 2.3 Minimal Attack Surface

The C shim has approximately 200 lines of code total. This is small enough
to be audited line-by-line and formally verified with tools like Frama-C
if desired. The functions have no global state, no heap allocation, and
no complex control flow.

## 3. C Shim API

### 3.1 `nvme_read_smart`

```c
/**
 * nvme_read_smart -- Read NVMe SMART/Health Information (Log Page 02h)
 *
 * @param fd      Open file descriptor for the NVMe device (e.g., /dev/nvme0n1)
 * @param smart   Pointer to caller-allocated nvme_smart_log structure
 *
 * @return  0 on success
 *         -EBADF   if fd is invalid
 *         -EIO     if the ioctl fails
 *         -EINVAL  if smart is NULL
 *
 * Thread safety: Safe to call concurrently on different fds.
 * Memory: Does not allocate. Writes to caller-provided buffer only.
 */
int nvme_read_smart(int fd, struct nvme_smart_log *smart);
```

**Consumed by Idris2 via:**

```idris
%foreign "C:nvme_read_smart,ochrance_shim"
prim__nvmeReadSmart : Int -> Ptr SmartLog -> PrimIO Int
```

### 3.2 `nvme_read_block`

```c
/**
 * nvme_read_block -- Read a single logical block from an NVMe namespace
 *
 * @param fd      Open file descriptor for the NVMe device
 * @param lba     Logical Block Address to read
 * @param buf     Pointer to caller-allocated buffer (must be >= len bytes)
 * @param len     Number of bytes to read (must equal logical block size)
 *
 * @return  0 on success
 *         -EBADF   if fd is invalid
 *         -EIO     if the read fails
 *         -EINVAL  if buf is NULL or len is 0
 *         -EFAULT  if buf is not accessible
 *
 * Thread safety: Safe to call concurrently on different fds.
 *                NOT safe to call concurrently on the same fd+lba.
 * Memory: Does not allocate. Writes to caller-provided buffer only.
 * Alignment: buf SHOULD be aligned to logical block size for optimal
 *            performance, but misaligned buffers are handled by the kernel.
 */
int nvme_read_block(int fd, uint64_t lba, void *buf, size_t len);
```

**Consumed by Idris2 via:**

```idris
%foreign "C:nvme_read_block,ochrance_shim"
prim__nvmeReadBlock : Int -> Bits64 -> Ptr Block -> Int -> PrimIO Int
```

### 3.3 `nvme_write_block`

```c
/**
 * nvme_write_block -- Write a single logical block to an NVMe namespace
 *
 * @param fd      Open file descriptor for the NVMe device
 * @param lba     Logical Block Address to write
 * @param buf     Pointer to data to write (must be >= len bytes)
 * @param len     Number of bytes to write (must equal logical block size)
 *
 * @return  0 on success
 *         -EBADF   if fd is invalid
 *         -EIO     if the write fails
 *         -EINVAL  if buf is NULL or len is 0
 *         -EROFS   if the device is read-only
 *
 * Thread safety: Safe to call concurrently on different fds.
 *                NOT safe to call concurrently on the same fd+lba.
 * Memory: Does not allocate. Reads from caller-provided buffer only.
 *
 * CAUTION: This function writes raw blocks. The caller (Idris2 L2/L3)
 *          is responsible for ensuring the write is part of a verified
 *          repair operation with a CoW snapshot.
 */
int nvme_write_block(int fd, uint64_t lba, const void *buf, size_t len);
```

**Consumed by Idris2 via:**

```idris
%foreign "C:nvme_write_block,ochrance_shim"
prim__nvmeWriteBlock : Int -> Bits64 -> Ptr Block -> Int -> PrimIO Int
```

## 4. Build and Linking

### 4.1 Shared Library

The C shims are compiled into a shared library `libochrance_shim.so`:

```makefile
# Makefile for ochrance-shim
CC = gcc
CFLAGS = -Wall -Wextra -Werror -O2 -fPIC -std=c11
LDFLAGS = -shared -lnvme

libochrance_shim.so: ochrance_shim.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
```

### 4.2 Idris2 Integration

The Idris2 build system (pack or idris2 directly) must be told where to
find the shared library:

```
-- In the .ipkg file:
opts = "--cg chez"
libs = ochrance_shim
```

### 4.3 Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| `libnvme` | >= 1.0 | NVMe management library (ioctl wrappers) |
| `libnvme-dev` | >= 1.0 | Headers for compilation |
| Linux kernel | >= 5.15 | NVMe driver with SMART support |

### 4.4 Header File

A single header file `ochrance_shim.h` declares all three functions:

```c
/* ochrance_shim.h -- Ochrance L1 C shim interface
 * SPDX-License-Identifier: PMPL-1.0-or-later
 * Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
 */

#ifndef OCHRANCE_SHIM_H
#define OCHRANCE_SHIM_H

#include <stdint.h>
#include <stddef.h>
#include <libnvme.h>

int nvme_read_smart(int fd, struct nvme_smart_log *smart);
int nvme_read_block(int fd, uint64_t lba, void *buf, size_t len);
int nvme_write_block(int fd, uint64_t lba, const void *buf, size_t len);

#endif /* OCHRANCE_SHIM_H */
```

## 5. Error Handling Contract

### 5.1 C Layer Errors

The C shims return negative `errno` values on failure. They never call
`exit()`, `abort()`, `longjmp()`, or any function that transfers control.
Errors are always reported by return value.

### 5.2 Idris2 Error Mapping

Idris2 maps C error codes to a sum type:

```idris
data IOError : Type where
  BadFd       : IOError                -- EBADF
  IOFailure   : IOError                -- EIO
  InvalidArg  : IOError                -- EINVAL
  ReadOnly    : IOError                -- EROFS
  AccessFault : IOError                -- EFAULT
  Unknown     : (errno : Int) -> IOError  -- anything else
```

### 5.3 Invariant: No Silent Failures

The C shim MUST NOT return 0 (success) if the operation did not complete
successfully. A partial read or partial write is an error (returns `-EIO`).

## 6. Testing Strategy

### 6.1 C Layer Tests

The C shims are tested in isolation using:

- **Mock NVMe device:** A loopback NVMe target (`nvmet`) for integration tests.
- **Error injection:** `dm-flakey` device-mapper target to simulate I/O errors.
- **Valgrind/ASan:** Memory safety verification (no leaks, no out-of-bounds).

### 6.2 FFI Integration Tests

Idris2 integration tests verify the full stack:

```idris
-- Test: reading SMART data returns a valid structure
testSmartRead : IO ()
testSmartRead = do
  dev <- openDevice "/dev/nvme0n1"
  Right smart <- readSmartLog dev
    | Left err => assertFailure ("SMART read failed: " ++ show err)
  assert (temperature smart > 0)
  assert (temperature smart < 100)  -- degrees Celsius, sanity check
  closeDevice dev
```

### 6.3 Property-Based Tests

Using Hedgehog (via Idris2 bindings) to verify invariants:

- Any valid `Fin n` offset produces a successful read on a healthy device.
- Writing a block and reading it back yields identical bytes.
- SMART data fields are within documented NVMe specification ranges.

## 7. Future FFI Extensions

### 7.1 Memory Module (Rust FFI)

The memory module will use Rust instead of C for its FFI layer:

```idris
-- Future: Rust FFI for memory page introspection
%foreign "C:memory_read_page,ochrance_memory_shim"
prim__memoryReadPage : Bits64 -> Ptr Page -> PrimIO Int
```

Rust provides memory safety guarantees that C does not, which is valuable
for a module that introspects process memory. The Idris2 side remains
unchanged -- it still calls via `%foreign` with C ABI compatibility.

### 7.2 Network Module (eBPF)

The network module will use eBPF programs loaded via `libbpf`:

```idris
-- Future: eBPF FFI for packet observation
%foreign "C:network_attach_observer,ochrance_network_shim"
prim__networkAttachObserver : Int -> Ptr BpfProgram -> PrimIO Int
```

eBPF programs run in kernel space and are verified by the kernel's BPF
verifier, providing a second layer of safety beyond Idris2's type system.

### 7.3 Crypto Module (HACL*)

The crypto module will link to HACL*, a formally verified cryptographic
library:

```idris
-- Future: HACL* FFI for verified cryptographic operations
%foreign "C:Hacl_SHA2_256_hash,libhacl"
prim__sha256Hash : Ptr Input -> Bits32 -> Ptr Output -> PrimIO ()
```

HACL* provides machine-checked proofs of functional correctness, memory
safety, and constant-time execution. This complements Idris2's proofs
over the protocol level.

## 8. Cross-References

| Document | Relevance |
|----------|-----------|
| `docs/ARCHITECTURE.md` | L0-L5 layer definitions |
| `docs/A2ML-SPEC.md` | Output format of L2 verification |
| `docs/L4-POLICIES.md` | Policy evaluation over verified state |
| `ffi/` | FFI source code directory |
| `src/abi/` | Idris2 ABI definitions |
