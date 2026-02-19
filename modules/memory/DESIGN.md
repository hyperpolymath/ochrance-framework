# Memory Module — Design Document

**Status**: Future work (not yet implemented)

## Overview

The memory verification subsystem will provide integrity checking for
in-memory data structures. This includes:

- Verified memory allocator state (free lists, allocation maps)
- Stack canary verification via dependent types
- Heap integrity proofs (no dangling pointers, no double-frees)
- Memory-mapped file coherence checking

## Planned Modules

| Module                       | Purpose                              |
|------------------------------|--------------------------------------|
| `Ochrance.Memory.Types`      | Core types (regions, pages, mappings)|
| `Ochrance.Memory.Allocator`  | Verified allocator state tracking    |
| `Ochrance.Memory.Canary`     | Stack canary generation/verification |
| `Ochrance.Memory.Coherence`  | mmap coherence checking              |

## Verification Modes

- **Lax**: Check that allocation counts are consistent
- **Checked**: Verify guard pages and canary values
- **Attested**: Full pointer graph verification with ownership proofs

## Dependencies

- Requires `Ochrance.Framework.*` (core interface and proof types)
- Will use linear types for ownership tracking
- FFI to C for reading `/proc/self/maps` and memory-mapped regions

## Open Questions

- How to handle ASLR without leaking address information into proofs?
- Should the allocator model be generic or tied to a specific allocator (jemalloc, glibc)?
- Integration with Valgrind/AddressSanitizer for cross-validation?
