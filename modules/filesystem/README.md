# Filesystem Module

The filesystem verification subsystem for the Ochrance framework.

## Source Location

All source files live under `ochrance-core/Ochrance/Filesystem/` to match the
Idris2 module hierarchy (sourcedir = "ochrance-core"):

| Module                        | File                                        |
|-------------------------------|---------------------------------------------|
| `Ochrance.Filesystem.Types`   | `ochrance-core/Ochrance/Filesystem/Types.idr`  |
| `Ochrance.Filesystem.Merkle`  | `ochrance-core/Ochrance/Filesystem/Merkle.idr` |
| `Ochrance.Filesystem.Verify`  | `ochrance-core/Ochrance/Filesystem/Verify.idr` |
| `Ochrance.Filesystem.Repair`  | `ochrance-core/Ochrance/Filesystem/Repair.idr` |

## Overview

The filesystem module provides verified integrity checking for block-based
storage. It models storage as a vector of fixed-size blocks (4096 bytes),
with integrity tracked via Merkle trees.

### Verification Modes

- **Lax**: Checks block counts and metadata presence
- **Checked**: Verifies every block hash against the manifest
- **Attested**: Full Merkle tree reconstruction and root hash verification

### Repair

When verification fails, the repair module can restore blocks from a
known-good snapshot. Repair is atomic: either all corrupt blocks are
replaced, or the state is unchanged.

### NVMe FFI

Raw block I/O is handled by the C shim in `ffi/c/nvme_shim.c`, which
provides thin wrappers around Linux NVMe ioctls. The Idris2 code calls
these via `%foreign` declarations (to be added in `Ochrance.FFI.NVMe`).
