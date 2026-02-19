<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Ochrance Framework -- Claude Code Implementation Guide

> **Version:** 1.0.0-draft
> **Last updated:** 2026-02-19
> **Author:** Jonathan D.A. Jewell, The Open University
> **Purpose:** Week-by-week development plan with code templates, test
> specifications, and command references.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Project File Structure](#2-project-file-structure)
3. [Phase 1: Ochrance Core (Weeks 1-12)](#3-phase-1-ochrance-core-weeks-1-12)
4. [Phase 2: ECHIDNA + Idris2 Backend (Weeks 13-18)](#4-phase-2-echidna--idris2-backend-weeks-13-18)
5. [Phase 3: Neural Synthesis (Weeks 19-26)](#5-phase-3-neural-synthesis-weeks-19-26)
6. [Phase 4: Production and Thesis (Weeks 27-38)](#6-phase-4-production-and-thesis-weeks-27-38)
7. [Test Specifications](#7-test-specifications)
8. [Command Reference](#8-command-reference)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

### 1.1 Required Software

| Software | Version | Installation |
|----------|---------|-------------|
| Idris2 | >= 0.7.0 | `pack install idris2` or build from source |
| GCC | >= 12 | `dnf install gcc` (Fedora) |
| libnvme | >= 1.0 | `dnf install libnvme-devel` |
| Rust | nightly | `asdf install rust nightly` |
| Julia | >= 1.10 | `asdf install julia 1.10` |
| Podman | >= 4.0 | `dnf install podman` |
| just | >= 1.0 | `cargo install just` |

### 1.2 Idris2 Setup

```bash
# Install Idris2 via pack (recommended)
git clone https://github.com/stefan-hoeck/idris2-pack.git
cd idris2-pack
make install

# Verify installation
idris2 --version
# Expected: Idris 2, version 0.7.0-...

# Install Idris2 libraries needed by Ochrance
pack install hedgehog   # property-based testing
pack install elab-util  # elaboration utilities
```

### 1.3 Development Environment

```bash
# Clone the repository (canonical location)
cd ~/Documents/hyperpolymath-repos
# ochrance-framework should already exist

# Verify structure
ls ochrance-framework/
# Expected: src/ modules/ ffi/ docs/ tests/ ...

# Set up the Justfile
cd ochrance-framework
just --list
```

### 1.4 NVMe Test Setup

For development and testing without real NVMe hardware:

```bash
# Create a loopback NVMe target using nvmet
# (Requires root; use in a VM or test machine)
sudo modprobe nvmet
sudo modprobe nvme-loop

# Create a RAM-backed NVMe namespace (1 GB)
sudo mkdir -p /sys/kernel/config/nvmet/subsystems/ochrance-test
sudo bash -c 'echo 1 > /sys/kernel/config/nvmet/subsystems/ochrance-test/attr_allow_any_host'
sudo mkdir -p /sys/kernel/config/nvmet/subsystems/ochrance-test/namespaces/1
sudo bash -c 'echo /tmp/ochrance-test.img > /sys/kernel/config/nvmet/subsystems/ochrance-test/namespaces/1/device_path'

# Alternative: use a file-backed block device for simpler testing
dd if=/dev/zero of=/tmp/ochrance-test.img bs=1M count=1024
sudo losetup /dev/loop0 /tmp/ochrance-test.img
```

---

## 2. Project File Structure

```
ochrance-framework/
├── src/
│   ├── abi/                         # Idris2 ABI definitions (existing)
│   │   ├── Types.idr
│   │   ├── Layout.idr
│   │   └── Foreign.idr
│   ├── core/                        # Framework core (NEW)
│   │   ├── Ochrance/
│   │   │   ├── Core.idr             # VerifiedSubsystem interface
│   │   │   ├── State.idr            # VerifiedState type
│   │   │   ├── Merkle.idr           # Merkle tree construction + proofs
│   │   │   ├── Hash.idr             # HashAlgo type family
│   │   │   ├── Ephapax.idr          # Linear-type repair tokens
│   │   │   ├── Policy.idr           # Policy type + composition
│   │   │   └── A2ML/
│   │   │       ├── Types.idr        # A2ML data types
│   │   │       ├── Parser.idr       # Recursive descent parser
│   │   │       ├── Serialiser.idr   # Pretty-printer
│   │   │       └── Validate.idr     # Document validation
│   │   └── ochrance-core.ipkg       # Idris2 package file
│   └── tui/                         # TUI and telemetry (NEW)
│       ├── Ochrance/
│       │   ├── TUI/
│       │   │   ├── Main.idr         # TUI entry point
│       │   │   ├── MerkleView.idr   # Merkle tree visualisation
│       │   │   ├── PolicyDash.idr   # Policy evaluation dashboard
│       │   │   └── Diagnostics.idr  # q/p/z semantic diagnostics
│       │   └── Telemetry/
│       │       ├── JsonLines.idr    # JSON-lines structured logging
│       │       └── OpenTelemetry.idr # OTel span emission
│       └── ochrance-tui.ipkg
├── modules/
│   ├── filesystem/                  # Reference implementation (NEW)
│   │   ├── Ochrance/
│   │   │   └── Filesystem/
│   │   │       ├── Module.idr       # VerifiedSubsystem implementation
│   │   │       ├── NVMe.idr         # NVMe FFI bindings
│   │   │       ├── Smart.idr        # SMART data parsing
│   │   │       ├── Snapshot.idr     # CoW snapshot management
│   │   │       └── Repair.idr       # Repair actions
│   │   ├── ochrance-filesystem.ipkg
│   │   └── shim/                    # C shims
│   │       ├── ochrance_shim.c      # ~200 lines of C
│   │       ├── ochrance_shim.h      # Header file
│   │       └── Makefile             # Build shared library
│   ├── memory/                      # Future
│   ├── network/                     # Future
│   └── crypto/                      # Future
├── ffi/                             # FFI source (existing dir)
│   └── zig/                         # Zig FFI (from RSR template)
├── tests/
│   ├── core/                        # Core framework tests
│   │   ├── TestA2MLParser.idr
│   │   ├── TestA2MLRoundTrip.idr
│   │   ├── TestMerkle.idr
│   │   ├── TestEphapax.idr
│   │   └── TestPolicy.idr
│   ├── filesystem/                  # Filesystem module tests
│   │   ├── TestNVMe.idr
│   │   ├── TestSmart.idr
│   │   ├── TestSnapshot.idr
│   │   └── TestRepair.idr
│   ├── integration/                 # End-to-end tests
│   │   ├── TestFullVerification.idr
│   │   └── TestCorruptionDetection.idr
│   └── fuzz/                        # Fuzz testing
│       ├── fuzz_a2ml_parser.c       # AFL++ harness for A2ML parser
│       └── corpus/                  # Seed corpus for fuzzing
├── benchmarks/
│   ├── bench_merkle.idr             # Merkle tree construction benchmarks
│   ├── bench_verification.idr       # Full verification benchmarks
│   └── bench_a2ml.idr               # A2ML serialisation benchmarks
├── echidna/                         # ECHIDNA integration (Phase 2)
│   ├── src/
│   │   ├── idris2_backend/
│   │   │   ├── ast.rs               # Idris2 term AST
│   │   │   ├── codegen.rs           # Code generator
│   │   │   ├── templates.rs         # Proof templates
│   │   │   └── mod.rs
│   │   ├── bridge/
│   │   │   ├── api.rs               # Ochrance-ECHIDNA bridge API
│   │   │   └── witness.rs           # Proof witness serialisation
│   │   └── lib.rs
│   └── Cargo.toml
├── neural/                          # Neural synthesis (Phase 3)
│   ├── src/
│   │   ├── data/
│   │   │   ├── corpus.jl            # Proof corpus extraction
│   │   │   ├── features.jl          # Feature engineering
│   │   │   └── augment.jl           # Data augmentation
│   │   ├── model/
│   │   │   ├── architecture.jl      # Transformer architecture
│   │   │   ├── training.jl          # Training pipeline
│   │   │   └── inference.jl         # Beam search decoding
│   │   └── verify/
│   │       ├── loop.jl              # Verification loop
│   │       └── benchmark.jl         # Synthesis benchmarks
│   └── Project.toml                 # Julia project file
├── docs/                            # Documentation (this directory)
├── Justfile                         # Build commands
├── Containerfile                    # Container build
└── ochrance.ipkg                    # Top-level Idris2 package
```

---

## 3. Phase 1: Ochrance Core (Weeks 1-12)

### Week 1: A2ML Tokeniser

**Goal:** Implement the A2ML tokeniser that converts raw text into tokens.

**Files to create:**

- `src/core/Ochrance/A2ML/Types.idr`
- `src/core/Ochrance/A2ML/Lexer.idr` (optional, or inline in Parser)

**Code template:**

```idris
-- src/core/Ochrance/A2ML/Types.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.A2ML.Types

import Data.Vect

||| Hash algorithm identifier
public export
data HashAlgo = SHA256 | SHA3_256 | BLAKE3

||| A hash value: algorithm tag + raw bytes
public export
record HashValue where
  constructor MkHashValue
  algorithm : HashAlgo
  digest    : List Bits8

||| A2ML document value types
public export
data A2MLValue
  = StringVal String
  | HashVal HashValue
  | IntVal Integer
  | TimestampVal String     -- ISO 8601 string
  | ListVal (List A2MLValue)
  | BlobVal (List Bits8)    -- decoded base64
  | BoolVal Bool

||| A2ML field: key-value pair or nested block
public export
data A2MLField
  = KeyValue String A2MLValue
  | Block String (List A2MLField)

||| A2ML section
public export
record A2MLSection where
  constructor MkSection
  name   : String
  fields : List A2MLField

||| Complete A2ML document
public export
record A2MLDocument where
  constructor MkDocument
  version  : (Nat, Nat)
  sections : List A2MLSection

||| Parse errors with location information
public export
record ParseError where
  constructor MkParseError
  line     : Nat
  column   : Nat
  expected : String
  found    : String
```

**Tests:**

```idris
-- tests/core/TestA2MLParser.idr (stub)
-- TODO: Test that tokeniser handles all value types
-- TODO: Test that tokeniser rejects null bytes
-- TODO: Test that tokeniser handles UTF-8 correctly
-- TODO: Test error messages include line numbers
```

### Week 2: A2ML Parser (Recursive Descent)

**Goal:** Implement the recursive descent parser for A2ML documents.

**Files to create:**

- `src/core/Ochrance/A2ML/Parser.idr`

**Code template:**

```idris
-- src/core/Ochrance/A2ML/Parser.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.A2ML.Parser

import Ochrance.A2ML.Types

||| Parser state: remaining input + current position
record ParserState where
  constructor MkParserState
  input  : List Char
  line   : Nat
  column : Nat

||| Parser monad: state + error
Parser : Type -> Type
Parser a = ParserState -> Either ParseError (a, ParserState)

||| Parse the header line: "a2ml/1.0"
parseHeader : Parser (Nat, Nat)
parseHeader = do
  -- TODO: Parse "a2ml/" literal
  -- TODO: Parse version number (major.minor)
  -- TODO: Consume newline
  ?parseHeader_todo

||| Parse a section tag: "@name"
parseSectionTag : Parser String
parseSectionTag = do
  -- TODO: Parse '@' character
  -- TODO: Parse identifier
  ?parseSectionTag_todo

||| Parse a field value
parseValue : Parser A2MLValue
parseValue = do
  -- TODO: Try each value type in order:
  --   1. String (starts with '"')
  --   2. Hash (starts with hash algorithm name)
  --   3. Integer (starts with digit)
  --   4. Timestamp (starts with digit, contains 'T')
  --   5. List (starts with '[')
  --   6. Blob (starts with "base64(")
  --   7. Boolean ("true" or "false")
  ?parseValue_todo

||| Parse a complete section
parseSection : Parser A2MLSection
parseSection = do
  -- TODO: Parse section tag
  -- TODO: Parse opening '{'
  -- TODO: Parse fields until '}'
  -- TODO: Parse closing '}'
  ?parseSection_todo

||| Parse a complete A2ML document
export
parseA2ML : String -> Either ParseError A2MLDocument
parseA2ML input =
  let state = MkParserState (unpack input) 1 1
  in case runParser (do header <- parseHeader
                        sections <- many parseSection
                        pure (MkDocument header sections)) state of
       Left err => Left err
       Right (doc, _) => Right doc
```

**Tests to write:**

- Parse a minimal valid document (manifest + refs only).
- Parse a document with all five sections.
- Reject a document missing the header.
- Reject a document with an unknown hash algorithm.
- Reject a document exceeding the 16 MiB size limit.
- Reject a document with nesting depth > 8.

### Week 3: A2ML Serialiser and Round-Trip Tests

**Goal:** Implement the A2ML serialiser and verify round-trip property.

**Files to create:**

- `src/core/Ochrance/A2ML/Serialiser.idr`
- `tests/core/TestA2MLRoundTrip.idr`

**Code template:**

```idris
-- src/core/Ochrance/A2ML/Serialiser.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.A2ML.Serialiser

import Ochrance.A2ML.Types

||| Serialise a complete A2ML document to a string
export
serialiseA2ML : A2MLDocument -> String
serialiseA2ML doc =
  let header = "a2ml/" ++ show (fst doc.version) ++ "." ++ show (snd doc.version) ++ "\n"
      sections = concatMap serialiseSection doc.sections
  in header ++ sections

||| Serialise a single section
serialiseSection : A2MLSection -> String
serialiseSection section =
  -- TODO: "@" ++ name ++ " {\n" ++ fields ++ "}\n"
  ?serialiseSection_todo

||| Serialise a field (with indentation)
serialiseField : (indent : Nat) -> A2MLField -> String
serialiseField indent (KeyValue k v) =
  -- TODO: indent ++ key ++ ": " ++ value ++ "\n"
  ?serialiseField_kv_todo
serialiseField indent (Block k fields) =
  -- TODO: indent ++ key ++ " {\n" ++ fields ++ indent ++ "}\n"
  ?serialiseField_block_todo
```

**Round-trip property test:**

```idris
-- tests/core/TestA2MLRoundTrip.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module TestA2MLRoundTrip

import Hedgehog
import Ochrance.A2ML.Parser
import Ochrance.A2ML.Serialiser
import Ochrance.A2ML.Types

||| Generator for random A2ML documents
genA2MLDocument : Gen A2MLDocument
genA2MLDocument = do
  -- TODO: Generate random but valid A2ML documents
  ?genA2MLDocument_todo

||| Property: parse . serialise == id
prop_roundTrip : Property
prop_roundTrip = property $ do
  doc <- forAll genA2MLDocument
  let serialised = serialiseA2ML doc
  case parseA2ML serialised of
    Left err  => failWith Nothing ("Parse failed: " ++ show err)
    Right doc' => doc === doc'
```

### Weeks 3-5: VerifiedSubsystem Interface

**Goal:** Define the core framework types and interfaces.

**Files to create:**

- `src/core/Ochrance/Hash.idr`
- `src/core/Ochrance/State.idr`
- `src/core/Ochrance/Core.idr`
- `src/core/Ochrance/Ephapax.idr`
- `src/core/Ochrance/Policy.idr`

**Code template -- Hash.idr:**

```idris
-- src/core/Ochrance/Hash.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.Hash

import Data.Vect

||| Supported hash algorithms
public export
data HashAlgo = SHA256 | SHA3_256 | BLAKE3

||| Output length in bytes for each algorithm
public export
hashLen : HashAlgo -> Nat
hashLen SHA256   = 32
hashLen SHA3_256 = 32
hashLen BLAKE3   = 32

||| A hash output, indexed by algorithm
public export
data Hash : HashAlgo -> Type where
  MkHash : Vect (hashLen algo) Bits8 -> Hash algo

||| Hash equality is decidable
public export
DecEq (Hash algo) where
  decEq (MkHash xs) (MkHash ys) = ?decEqHash_todo
```

**Code template -- Ephapax.idr:**

```idris
-- src/core/Ochrance/Ephapax.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.Ephapax

||| Repair actions that can be performed by L3
public export
data RepairAction
  = RestoreBlock Nat          -- restore block at given index
  | RewriteMetadata String    -- rewrite metadata for given path
  | QuarantineFile String     -- quarantine file at given path
  | RebuildIndex              -- rebuild filesystem index

||| An Ephapax token is a linear-type value that MUST be consumed
||| exactly once. It represents a pending repair action.
|||
||| The linearity annotation (1) means:
|||   - You cannot ignore an Ephapax token (the repair MUST happen)
|||   - You cannot use it twice (the repair happens EXACTLY once)
|||   - The Idris2 compiler enforces this at compile time
public export
data Ephapax : RepairAction -> Type where
  MkEphapax : (1 _ : RepairAction) -> Ephapax action

||| Result of applying a repair
public export
data RepairResult
  = RepairSuccess
  | RepairFailed String
  | RepairRolledBack String

||| Consume an Ephapax token by performing the repair.
||| The (1 token) annotation enforces linear consumption.
export
applyRepair : (1 token : Ephapax action) -> IO RepairResult
applyRepair (MkEphapax action) = do
  -- TODO: Perform the repair action
  -- TODO: This is the ONLY way to consume the token
  ?applyRepair_todo
```

**Code template -- Core.idr:**

```idris
-- src/core/Ochrance/Core.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.Core

import Ochrance.Hash
import Ochrance.State

||| Unique identifier for a verifiable unit (block, page, packet, etc.)
public export
data UnitId = MkUnitId Nat

||| Raw bytes read from a unit
public export
RawBytes : Type
RawBytes = List Bits8

||| Health status reported by a subsystem
public export
data HealthStatus
  = Healthy
  | Degraded String    -- operational but with warnings
  | Critical String    -- immediate attention needed

||| Read error from a subsystem
public export
data ReadError
  = DeviceNotFound
  | IOFailure String
  | PermissionDenied

||| Write error from a subsystem
public export
data WriteError
  = WriteIOFailure String
  | ReadOnlyDevice
  | WritePermissionDenied

||| The VerifiedSubsystem interface.
||| Any module implementing this gets Merkle tree verification,
||| Ephapax repair, policy evaluation, and TUI integration.
public export
interface Monad m => VerifiedSubsystem (m : Type -> Type) where
  ||| Enumerate all units managed by this subsystem
  enumerateUnits : m (List UnitId)

  ||| Read a single unit
  readUnit : UnitId -> m (Either ReadError RawBytes)

  ||| Write a single unit (used during repair only)
  writeUnit : UnitId -> RawBytes -> m (Either WriteError ())

  ||| Hash a unit's contents for Merkle tree construction
  hashUnit : {algo : HashAlgo} -> RawBytes -> Hash algo

  ||| Subsystem-specific health check
  healthCheck : m HealthStatus
```

### Weeks 5-10: Filesystem Module

**Goal:** Implement the filesystem module as the VerifiedSubsystem reference.

**Files to create:**

- `modules/filesystem/shim/ochrance_shim.h`
- `modules/filesystem/shim/ochrance_shim.c`
- `modules/filesystem/shim/Makefile`
- `modules/filesystem/Ochrance/Filesystem/NVMe.idr`
- `modules/filesystem/Ochrance/Filesystem/Smart.idr`
- `modules/filesystem/Ochrance/Filesystem/Module.idr`
- `modules/filesystem/Ochrance/Filesystem/Snapshot.idr`
- `modules/filesystem/Ochrance/Filesystem/Repair.idr`

**Code template -- ochrance_shim.c:**

```c
/* ochrance_shim.c -- Ochrance L1 C shim layer
 * SPDX-License-Identifier: PMPL-1.0-or-later
 * Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
 *
 * This file is intentionally minimal (~200 lines).
 * All intelligence resides in Idris2 (L2+).
 * The C code is "too dumb to break invariants."
 */

#include "ochrance_shim.h"
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include <linux/nvme_ioctl.h>

int nvme_read_smart(int fd, struct nvme_smart_log *smart) {
    if (!smart) return -EINVAL;

    struct nvme_passthru_cmd cmd = {0};
    cmd.opcode = 0x02;   /* Admin: Get Log Page */
    cmd.nsid   = 0xFFFFFFFF;
    cmd.addr   = (__u64)(uintptr_t)smart;
    cmd.data_len = sizeof(*smart);
    cmd.cdw10  = 0x02 | (((sizeof(*smart) / 4) - 1) << 16);

    int ret = ioctl(fd, NVME_IOCTL_ADMIN_CMD, &cmd);
    if (ret < 0) return -errno;
    return 0;
}

int nvme_read_block(int fd, uint64_t lba, void *buf, size_t len) {
    if (!buf || len == 0) return -EINVAL;

    /* TODO: Implement NVMe read command via ioctl
     * Use NVME_IOCTL_IO_CMD with opcode 0x02 (Read) */
    struct nvme_passthru_cmd cmd = {0};
    cmd.opcode = 0x02;   /* NVM: Read */
    cmd.nsid   = 1;      /* TODO: parameterise namespace */
    cmd.addr   = (__u64)(uintptr_t)buf;
    cmd.data_len = len;
    cmd.cdw10  = lba & 0xFFFFFFFF;
    cmd.cdw11  = (lba >> 32) & 0xFFFFFFFF;
    cmd.cdw12  = 0;      /* Number of logical blocks - 1 */

    int ret = ioctl(fd, NVME_IOCTL_IO_CMD, &cmd);
    if (ret < 0) return -errno;
    return 0;
}

int nvme_write_block(int fd, uint64_t lba, const void *buf, size_t len) {
    if (!buf || len == 0) return -EINVAL;

    /* TODO: Implement NVMe write command via ioctl
     * Use NVME_IOCTL_IO_CMD with opcode 0x01 (Write) */
    struct nvme_passthru_cmd cmd = {0};
    cmd.opcode = 0x01;   /* NVM: Write */
    cmd.nsid   = 1;      /* TODO: parameterise namespace */
    cmd.addr   = (__u64)(uintptr_t)buf;
    cmd.data_len = len;
    cmd.cdw10  = lba & 0xFFFFFFFF;
    cmd.cdw11  = (lba >> 32) & 0xFFFFFFFF;
    cmd.cdw12  = 0;      /* Number of logical blocks - 1 */

    int ret = ioctl(fd, NVME_IOCTL_IO_CMD, &cmd);
    if (ret < 0) return -errno;
    return 0;
}
```

**Code template -- Makefile:**

```makefile
# modules/filesystem/shim/Makefile
# SPDX-License-Identifier: PMPL-1.0-or-later

CC      = gcc
CFLAGS  = -Wall -Wextra -Werror -O2 -fPIC -std=c11
LDFLAGS = -shared -lnvme

TARGET  = libochrance_shim.so
SRC     = ochrance_shim.c

.PHONY: all clean install test

all: $(TARGET)

$(TARGET): $(SRC) ochrance_shim.h
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	install -Dm755 $(TARGET) /usr/local/lib/$(TARGET)

test: $(TARGET)
	@echo "C shim tests require nvmet loopback target"
	@echo "See docs/IMPLEMENTATION-GUIDE.md for NVMe test setup"
```

**Code template -- NVMe.idr (FFI bindings):**

```idris
-- modules/filesystem/Ochrance/Filesystem/NVMe.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.Filesystem.NVMe

import System.FFI

||| FFI binding to the C shim: read NVMe SMART data
%foreign "C:nvme_read_smart,ochrance_shim"
prim__nvmeReadSmart : Int -> AnyPtr -> PrimIO Int

||| FFI binding to the C shim: read a single block
%foreign "C:nvme_read_block,ochrance_shim"
prim__nvmeReadBlock : Int -> Bits64 -> AnyPtr -> Int -> PrimIO Int

||| FFI binding to the C shim: write a single block
%foreign "C:nvme_write_block,ochrance_shim"
prim__nvmeWriteBlock : Int -> Bits64 -> AnyPtr -> Int -> PrimIO Int

||| Device handle (wraps an open file descriptor)
public export
record DeviceHandle where
  constructor MkDeviceHandle
  fd : Int
  totalBlocks : Nat
  blockSize : Nat

||| Open an NVMe device by path
export
openDevice : String -> IO (Either String DeviceHandle)
openDevice path = do
  -- TODO: open the device file
  -- TODO: query total blocks and block size via NVMe Identify
  ?openDevice_todo

||| Close a device handle
export
closeDevice : DeviceHandle -> IO ()
closeDevice dev = do
  -- TODO: close the file descriptor
  ?closeDevice_todo

||| Read a block with bounds checking via Fin type
export
readBlock : (dev : DeviceHandle)
         -> (offset : Fin (totalBlocks dev))
         -> IO (Either String (List Bits8))
readBlock dev offset = do
  -- TODO: Allocate buffer
  -- TODO: Call prim__nvmeReadBlock
  -- TODO: Convert result
  ?readBlock_todo
```

**Code template -- Merkle.idr:**

```idris
-- src/core/Ochrance/Merkle.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.Merkle

import Ochrance.Hash
import Data.Vect

||| Merkle tree indexed by depth and hash algorithm
public export
data MerkleTree : (depth : Nat) -> (algo : HashAlgo) -> Type where
  ||| A leaf node containing the hash of a single block
  Leaf : (blockHash : Hash algo) -> MerkleTree 0 algo
  ||| An internal node with a combined hash and two children
  Node : (nodeHash : Hash algo)
      -> (left : MerkleTree d algo)
      -> (right : MerkleTree d algo)
      -> MerkleTree (S d) algo

||| A Merkle inclusion proof: the path from a leaf to the root
public export
data MerklePath : (depth : Nat) -> (algo : HashAlgo) -> Type where
  Here  : MerklePath 0 algo
  GoLeft  : (sibling : Hash algo) -> MerklePath d algo -> MerklePath (S d) algo
  GoRight : (sibling : Hash algo) -> MerklePath d algo -> MerklePath (S d) algo

||| Verify that a leaf hash is included in a tree with the given root
export
verifyInclusion : {algo : HashAlgo}
               -> (leafHash : Hash algo)
               -> (root : Hash algo)
               -> (path : MerklePath depth algo)
               -> Bool
verifyInclusion leafHash root Here = leafHash == root
verifyInclusion leafHash root (GoLeft sibling rest) =
  let combined = combineHashes leafHash sibling
  in verifyInclusion combined root rest
verifyInclusion leafHash root (GoRight sibling rest) =
  let combined = combineHashes sibling leafHash
  in verifyInclusion combined root rest

||| Construct a Merkle tree from a list of block hashes
export
buildTree : {algo : HashAlgo}
         -> (hashes : List (Hash algo))
         -> (depth : Nat ** MerkleTree depth algo)
buildTree hashes =
  -- TODO: Pair up hashes, combine, recurse
  -- TODO: Handle odd-length lists (duplicate last)
  ?buildTree_todo

||| Proof that a Merkle tree is complete (all blocks present)
public export
data Complete : MerkleTree d algo -> List (Hash algo) -> Type where
  -- TODO: Define completeness proof structure
```

### Weeks 10-12: TUI and Telemetry

**Goal:** Implement the user-facing diagnostic layer.

**Code template -- Diagnostics.idr:**

```idris
-- src/tui/Ochrance/TUI/Diagnostics.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Ochrance.TUI.Diagnostics

||| Semantic diagnostic codes
||| q = quiescent (all good)
||| p = perturbation (anomaly detected)
||| z = zero-trust (integrity violation)
public export
data DiagnosticLevel = Q | P | Z

||| A diagnostic message with semantic code
public export
record Diagnostic where
  constructor MkDiagnostic
  level   : DiagnosticLevel
  code    : String        -- e.g., "q001", "p042", "z001"
  message : String
  detail  : Maybe String  -- optional extended detail

||| Format a diagnostic for terminal output
export
formatDiagnostic : Diagnostic -> String
formatDiagnostic diag =
  let prefix = case diag.level of
                 Q => "[q] "  -- green in TUI
                 P => "[p] "  -- yellow in TUI
                 Z => "[z] "  -- red in TUI
  in prefix ++ diag.code ++ ": " ++ diag.message
```

---

## 4. Phase 2: ECHIDNA + Idris2 Backend (Weeks 13-18)

### Weeks 13-15: Idris2 AST and Code Generator

**Files to create:**

- `echidna/src/idris2_backend/ast.rs`
- `echidna/src/idris2_backend/codegen.rs`
- `echidna/src/idris2_backend/templates.rs`
- `echidna/Cargo.toml`

**Code template -- Cargo.toml:**

```toml
# echidna/Cargo.toml
# SPDX-License-Identifier: PMPL-1.0-or-later

[package]
name = "ochrance-echidna"
version = "0.1.0"
edition = "2021"
authors = ["Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>"]
description = "ECHIDNA Idris2 prover backend for Ochrance"
license = "PMPL-1.0-or-later"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"
```

**Code template -- ast.rs:**

```rust
// echidna/src/idris2_backend/ast.rs
// SPDX-License-Identifier: PMPL-1.0-or-later

use serde::{Deserialize, Serialize};

/// Multiplicity annotation for Quantitative Type Theory
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Multiplicity {
    /// Erased at runtime (compile-time only)
    Zero,
    /// Linear: must be used exactly once
    One,
    /// Unrestricted: can be used any number of times
    Omega,
}

/// Idris2 term representation for code generation.
///
/// This is a subset of Idris2's core language sufficient
/// for generating filesystem verification proofs.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum IdrisTerm {
    /// Variable reference
    Var(String),

    /// Lambda abstraction
    Lam {
        name: String,
        multiplicity: Multiplicity,
        ty: Box<IdrisTerm>,
        body: Box<IdrisTerm>,
    },

    /// Function application
    App(Box<IdrisTerm>, Box<IdrisTerm>),

    /// Pi type (dependent function type)
    Pi {
        name: String,
        multiplicity: Multiplicity,
        domain: Box<IdrisTerm>,
        codomain: Box<IdrisTerm>,
    },

    /// Data constructor application
    Con(String, Vec<IdrisTerm>),

    /// Case expression
    Case {
        scrutinee: Box<IdrisTerm>,
        cases: Vec<(Pattern, IdrisTerm)>,
    },

    /// Let binding
    Let {
        name: String,
        ty: Box<IdrisTerm>,
        val: Box<IdrisTerm>,
        body: Box<IdrisTerm>,
    },

    /// Type universe
    Type,

    /// Rewrite rule application
    Rewrite {
        rule: Box<IdrisTerm>,
        body: Box<IdrisTerm>,
    },

    /// Hole (for incremental proof construction)
    Hole(String),
}

/// Pattern for case expressions
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Pattern {
    /// Constructor pattern
    ConPat(String, Vec<String>),
    /// Wildcard pattern
    Wildcard,
    /// Variable pattern
    VarPat(String),
}
```

### Weeks 15-17: Proof Search Integration

**Code template -- templates.rs:**

```rust
// echidna/src/idris2_backend/templates.rs
// SPDX-License-Identifier: PMPL-1.0-or-later

use crate::idris2_backend::ast::*;

/// Generate a Merkle tree completeness proof template.
///
/// Given: number of blocks and tree depth
/// Produces: an Idris2 proof term skeleton with holes
pub fn merkle_completeness_template(block_count: usize, depth: usize) -> IdrisTerm {
    // TODO: Generate the proof structure
    //
    // The proof proceeds by induction on the block list:
    // - Base case: empty list is trivially complete
    // - Inductive case: find the block in the tree (via auto-search),
    //   then recurse on the remaining blocks
    IdrisTerm::Hole("merkle_completeness_todo".to_string())
}

/// Generate a hash consistency proof template.
///
/// Given: a Merkle tree
/// Produces: a proof that every internal node's hash equals
///           H(left.hash || right.hash)
pub fn hash_consistency_template(depth: usize) -> IdrisTerm {
    // TODO: Generate the proof by structural induction on the tree
    IdrisTerm::Hole("hash_consistency_todo".to_string())
}

/// Generate a timestamp monotonicity proof template.
///
/// Given: two VerifiedState values
/// Produces: a proof that the second timestamp is strictly greater
pub fn timestamp_monotonicity_template() -> IdrisTerm {
    // TODO: Generate comparison proof
    IdrisTerm::Hole("timestamp_monotonicity_todo".to_string())
}
```

### Week 18: Ochrance-ECHIDNA Bridge

**Code template -- bridge/api.rs:**

```rust
// echidna/src/bridge/api.rs
// SPDX-License-Identifier: PMPL-1.0-or-later

use crate::idris2_backend::ast::IdrisTerm;
use crate::idris2_backend::codegen::generate_idris2;
use std::process::Command;

/// A proof request from Ochrance to ECHIDNA
#[derive(Debug)]
pub struct ProofRequest {
    /// The property to prove (as an Idris2 type)
    pub goal: String,
    /// Available context (hypotheses, known facts)
    pub context: Vec<String>,
    /// Maximum time budget in milliseconds
    pub timeout_ms: u64,
}

/// Result of a proof search
#[derive(Debug)]
pub enum ProofResult {
    /// Proof found and verified
    Verified {
        /// The Idris2 proof term
        proof: IdrisTerm,
        /// Serialised witness for A2ML embedding
        witness: Vec<u8>,
        /// Time taken in milliseconds
        time_ms: u64,
    },
    /// Proof search timed out
    Timeout,
    /// Proof search failed (goal may be unprovable)
    Failed(String),
}

/// Search for a proof of the given goal.
///
/// This is the main entry point from Ochrance into ECHIDNA.
pub fn search_proof(request: ProofRequest) -> ProofResult {
    // TODO: 1. Translate goal to ECHIDNA internal representation
    // TODO: 2. Run tactic engine (symbolic + neural)
    // TODO: 3. If proof found, generate Idris2 code
    // TODO: 4. Compile and verify with Idris2
    // TODO: 5. Serialise witness for A2ML
    ProofResult::Failed("Not yet implemented".to_string())
}

/// Verify an Idris2 proof by compiling it with the type checker.
///
/// Returns true if the proof type-checks successfully.
pub fn verify_with_idris2(proof_source: &str) -> Result<bool, String> {
    // Write proof to a temporary file
    let temp_path = "/tmp/ochrance_proof_check.idr";
    std::fs::write(temp_path, proof_source)
        .map_err(|e| format!("Failed to write proof file: {}", e))?;

    // Run Idris2 type checker
    let output = Command::new("idris2")
        .arg("--check")
        .arg(temp_path)
        .output()
        .map_err(|e| format!("Failed to run Idris2: {}", e))?;

    Ok(output.status.success())
}
```

---

## 5. Phase 3: Neural Synthesis (Weeks 19-26)

### Weeks 19-22: Training Data Pipeline

**Files to create:**

- `neural/Project.toml`
- `neural/src/data/corpus.jl`
- `neural/src/data/features.jl`

**Code template -- Project.toml:**

```toml
# neural/Project.toml
# SPDX-License-Identifier: PMPL-1.0-or-later

name = "OchranceNeural"
uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
authors = ["Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>"]
version = "0.1.0"

[deps]
Flux = "587475ba-b771-5e3f-ad9e-33799f191a9c"
Transformers = "21ca0261-441d-5571-ada7-03e74c0159d4"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
```

**Code template -- corpus.jl:**

```julia
# neural/src/data/corpus.jl
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

"""
Proof corpus extraction for neural proof synthesis training.

Extracts proof terms from:
1. Idris2 standard library (base, contrib)
2. Ochrance filesystem module proofs
3. Synthetic proofs from symbolic search
"""
module ProofCorpus

using JSON3

"""
A single proof sample for training.
"""
struct ProofSample
    goal::String           # The type to prove
    context::Vector{String} # Available hypotheses
    proof::String          # The proof term
    tactics::Vector{String} # Tactic sequence (if available)
    source::String         # Where this proof came from
end

"""
    extract_from_idris2_lib(lib_path::String) -> Vector{ProofSample}

Extract proof samples from Idris2 library source files.
Parses `.idr` files and extracts type signatures paired with
their implementations.
"""
function extract_from_idris2_lib(lib_path::String)::Vector{ProofSample}
    samples = ProofSample[]

    # TODO: Walk the library directory
    # TODO: Parse each .idr file
    # TODO: Extract (type_signature, implementation) pairs
    # TODO: Filter for proofs (implementations of propositions)
    # TODO: Return as ProofSample vector

    return samples
end

"""
    extract_from_ochrance(ochrance_path::String) -> Vector{ProofSample}

Extract proof samples from Ochrance framework source.
Focuses on Merkle tree proofs, policy proofs, and completeness proofs.
"""
function extract_from_ochrance(ochrance_path::String)::Vector{ProofSample}
    samples = ProofSample[]

    # TODO: Parse Ochrance Idris2 source files
    # TODO: Extract verification proofs
    # TODO: Tag with domain (merkle, policy, completeness, etc.)

    return samples
end

"""
    build_corpus(; idris2_lib, ochrance_path, output_path) -> Nothing

Build the complete training corpus and write to disk.
"""
function build_corpus(;
    idris2_lib::String = "",
    ochrance_path::String = "",
    output_path::String = "corpus.json"
)
    lib_samples = extract_from_idris2_lib(idris2_lib)
    ochrance_samples = extract_from_ochrance(ochrance_path)

    all_samples = vcat(lib_samples, ochrance_samples)

    @info "Corpus built" total=length(all_samples) lib=length(lib_samples) ochrance=length(ochrance_samples)

    open(output_path, "w") do io
        JSON3.write(io, all_samples)
    end
end

end # module
```

### Weeks 22-26: Neural Model and Verification Loop

**Code template -- architecture.jl:**

```julia
# neural/src/model/architecture.jl
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

"""
Transformer architecture for proof synthesis.

Input: tokenised proof goal (the type to prove)
Output: tokenised proof term (the implementation)
"""
module ProofModel

using Flux
using Flux: @functor

"""
Configuration for the proof synthesis model.
"""
Base.@kwdef struct ModelConfig
    vocab_size::Int = 32000
    d_model::Int = 512
    nhead::Int = 8
    num_encoder_layers::Int = 6
    num_decoder_layers::Int = 6
    dim_feedforward::Int = 2048
    dropout::Float64 = 0.1
    max_seq_len::Int = 2048
end

"""
    build_model(config::ModelConfig) -> Chain

Build the sequence-to-sequence proof synthesis model.
"""
function build_model(config::ModelConfig)
    # TODO: Build encoder-decoder transformer
    # TODO: Add positional encoding
    # TODO: Add vocabulary embedding and output projection

    # Placeholder structure
    return Chain(
        Dense(config.d_model, config.d_model, relu),
        Dense(config.d_model, config.vocab_size)
    )
end

"""
    beam_search(model, goal_tokens; beam_width=16, max_depth=100)

Generate proof candidates using beam search decoding.
Returns a list of (proof_tokens, score) pairs, sorted by score.
"""
function beam_search(model, goal_tokens::Vector{Int};
                     beam_width::Int=16, max_depth::Int=100)
    # TODO: Implement beam search over the decoder
    # TODO: Return top-k candidates with scores

    return [(Int[], 0.0)]  # placeholder
end

end # module
```

---

## 6. Phase 4: Production and Thesis (Weeks 27-38)

### Weeks 27-32: Production Hardening

**Containerfile template:**

```dockerfile
# Containerfile
# SPDX-License-Identifier: PMPL-1.0-or-later
# Build stage: compile Ochrance from source
FROM cgr.dev/chainguard/wolfi-base:latest AS build

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    libnvme-dev \
    make

# Copy C shims and build
COPY modules/filesystem/shim/ /build/shim/
WORKDIR /build/shim
RUN make

# Runtime stage: minimal image
FROM cgr.dev/chainguard/static:latest

COPY --from=build /build/shim/libochrance_shim.so /usr/local/lib/
# TODO: Copy compiled Idris2 binary

ENTRYPOINT ["/usr/local/bin/ochrance"]
```

**Justfile recipes:**

```just
# Justfile
# SPDX-License-Identifier: PMPL-1.0-or-later

# Build the C shim shared library
build-shim:
    cd modules/filesystem/shim && make

# Build the Idris2 core library
build-core:
    cd src/core && idris2 --build ochrance-core.ipkg

# Build the filesystem module
build-filesystem: build-shim
    cd modules/filesystem && idris2 --build ochrance-filesystem.ipkg

# Build everything
build: build-shim build-core build-filesystem

# Run all tests
test:
    cd tests/core && idris2 --build tests.ipkg && ./build/exec/tests
    cd tests/filesystem && idris2 --build tests.ipkg && ./build/exec/tests

# Run property-based tests
test-props:
    cd tests/core && idris2 --build props.ipkg && ./build/exec/props

# Fuzz the A2ML parser
fuzz:
    cd tests/fuzz && afl-fuzz -i corpus/ -o findings/ -- ./fuzz_a2ml_parser

# Run benchmarks
bench:
    cd benchmarks && idris2 --build bench.ipkg && ./build/exec/bench

# Build container image
container:
    podman build -t ochrance-framework:latest -f Containerfile .

# Clean all build artifacts
clean:
    cd modules/filesystem/shim && make clean
    rm -rf build/
    cd src/core && idris2 --clean ochrance-core.ipkg
    cd modules/filesystem && idris2 --clean ochrance-filesystem.ipkg

# Verify the project with panic-attack
security-scan:
    panic-attack assail . --output /tmp/ochrance-scan.json

# Run echidna proofing
proof-check:
    echidna proof . --output /tmp/ochrance-proofs.json
```

### Weeks 30-34: Evaluation

**Benchmark specification:**

```idris
-- benchmarks/bench_merkle.idr
-- SPDX-License-Identifier: PMPL-1.0-or-later

module BenchMerkle

import Ochrance.Merkle
import Ochrance.Hash
import System.Clock

||| Benchmark Merkle tree construction for various sizes
export
benchMerkleConstruction : IO ()
benchMerkleConstruction = do
  -- 1 GB = 262144 blocks of 4096 bytes
  let sizes = [1024, 4096, 16384, 65536, 262144, 1048576]
  for_ sizes $ \n => do
    hashes <- generateRandomHashes {algo = SHA256} n
    start <- clockTime Monotonic
    let (_ ** tree) = buildTree hashes
    end <- clockTime Monotonic
    let elapsed = timeDifference end start
    putStrLn $ "n=" ++ show n ++ " time=" ++ show elapsed ++ "ns"
```

---

## 7. Test Specifications

### 7.1 Unit Tests

| Test ID | Module | Description | Expected Result |
|---------|--------|-------------|-----------------|
| T001 | A2ML Parser | Parse minimal valid document | `Right doc` |
| T002 | A2ML Parser | Parse document with all sections | `Right doc` |
| T003 | A2ML Parser | Reject document without header | `Left (ParseError ...)` |
| T004 | A2ML Parser | Reject document with null bytes | `Left (ParseError ...)` |
| T005 | A2ML Parser | Reject document > 16 MiB | `Left (SizeExceeded ...)` |
| T006 | A2ML Parser | Reject nesting depth > 8 | `Left (NestingExceeded ...)` |
| T007 | A2ML Round-trip | `parse (serialise doc) == Right doc` | Property holds for 10000 random docs |
| T008 | Hash | SHA-256 of known input matches expected output | Exact match |
| T009 | Hash | SHA3-256 of known input matches expected output | Exact match |
| T010 | Hash | BLAKE3 of known input matches expected output | Exact match |
| T011 | Merkle | Build tree from 1 hash | Leaf node |
| T012 | Merkle | Build tree from 2 hashes | Depth-1 tree |
| T013 | Merkle | Build tree from 1024 hashes | Depth-10 tree |
| T014 | Merkle | Inclusion proof for leaf 0 | Verified |
| T015 | Merkle | Inclusion proof for last leaf | Verified |
| T016 | Merkle | Inclusion proof with wrong hash | Rejected |
| T017 | Ephapax | Consume token exactly once | Compiles |
| T018 | Ephapax | Attempt to consume token twice | Compile error (linear) |
| T019 | Ephapax | Attempt to ignore token | Compile error (linear) |
| T020 | Policy | Composed AllOf with all passing | `Yes prf` |
| T021 | Policy | Composed AllOf with one failing | `No contra` |
| T022 | Policy | Composed AnyOf with one passing | `Yes prf` |
| T023 | Policy | Composed AnyOf with none passing | `No contra` |

### 7.2 Integration Tests

| Test ID | Description | Setup | Expected Result |
|---------|-------------|-------|-----------------|
| I001 | Full verification of 1 GB filesystem | nvmet loopback | VerifiedState with valid Merkle root |
| I002 | Detect single bit flip | Inject corruption, verify | `P` diagnostic with block ID |
| I003 | Detect metadata corruption | Modify inode, verify | `Z` diagnostic with repair action |
| I004 | Repair from CoW snapshot | Corrupt block, repair | Block restored, `Q` diagnostic |
| I005 | A2ML attestation round-trip | Verify, serialise, parse, re-verify | Identical VerifiedState |
| I006 | SMART health degradation | Simulate via dm-flakey | `P` diagnostic with wear prediction |

### 7.3 Fuzz Tests

| Fuzz Target | Input | Goal |
|-------------|-------|------|
| A2ML parser | Random bytes | No crashes, no undefined behaviour |
| A2ML parser | Mutated valid documents | No crashes, graceful error handling |
| NVMe FFI | Random ioctl responses | No memory corruption, proper error propagation |
| Merkle construction | Random hash lists | Correct tree structure, no panics |

---

## 8. Command Reference

### 8.1 Idris2 Commands

```bash
# Type-check a module without building
idris2 --check src/core/Ochrance/Core.idr

# Build the core package
idris2 --build src/core/ochrance-core.ipkg

# Clean build artifacts
idris2 --clean src/core/ochrance-core.ipkg

# Interactive REPL with Ochrance loaded
idris2 --repl --package ochrance-core

# Generate documentation
idris2 --mkdoc src/core/ochrance-core.ipkg
```

### 8.2 C Shim Commands

```bash
# Build the shared library
cd modules/filesystem/shim
make

# Check with AddressSanitizer
make CFLAGS="-Wall -Wextra -Werror -O0 -g -fsanitize=address -fPIC"

# Static analysis with cppcheck
cppcheck --enable=all --std=c11 ochrance_shim.c

# (Optional) Formal verification with Frama-C
frama-c -wp ochrance_shim.c
```

### 8.3 Rust Commands (ECHIDNA backend)

```bash
# Build the ECHIDNA backend
cd echidna
cargo build --release

# Run tests
cargo test

# Run with logging
RUST_LOG=debug cargo run
```

### 8.4 Julia Commands (Neural synthesis)

```bash
# Activate the project environment
cd neural
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Build the training corpus
julia --project=. src/data/corpus.jl

# Train the model
julia --project=. src/model/training.jl

# Run synthesis benchmarks
julia --project=. src/verify/benchmark.jl
```

### 8.5 Container Commands

```bash
# Build the container image
podman build -t ochrance-framework:latest -f Containerfile .

# Run verification in a container
podman run --device=/dev/nvme0n1 ochrance-framework:latest verify /dev/nvme0n1

# Sign the container image
cerro-torre sign ochrance-framework:latest
```

---

## 9. Troubleshooting

### 9.1 Idris2 Issues

**Problem:** `Can't find package ochrance-core`

**Solution:** Ensure the `.ipkg` file is in the correct location and the
`IDRIS2_PACKAGE_PATH` environment variable includes the build directory:

```bash
export IDRIS2_PACKAGE_PATH=/var/mnt/eclipse/repos/ochrance-framework/src/core/build/ttc
```

**Problem:** `Linear variable used non-linearly`

**Solution:** This is Idris2 enforcing linear types (which is correct
behaviour). Check that the Ephapax token is consumed exactly once. Common
mistakes:

- Using the token in both branches of an `if-then-else` (only one branch
  executes, so this is non-linear).
- Passing the token to a function and also using it afterward.
- Pattern matching on the token without consuming it.

**Problem:** `idris2: out of memory`

**Solution:** Idris2 can use significant memory for complex types. Try:

```bash
# Increase stack size
ulimit -s unlimited

# Use Chez Scheme backend (default, most memory-efficient)
idris2 --cg chez --build ochrance-core.ipkg
```

### 9.2 C Shim Issues

**Problem:** `nvme_read_smart: Permission denied`

**Solution:** NVMe device access requires elevated privileges:

```bash
# Option 1: Run with capabilities (preferred)
sudo setcap cap_sys_rawio+ep /usr/local/bin/ochrance

# Option 2: Run as root (development only)
sudo ochrance verify /dev/nvme0n1

# Option 3: Use nvmet loopback (testing)
# See Section 1.4 for setup instructions
```

**Problem:** `error while loading shared libraries: libochrance_shim.so`

**Solution:** The shared library is not in the library path:

```bash
# Option 1: Install to system path
sudo make install  # in modules/filesystem/shim/

# Option 2: Set LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/var/mnt/eclipse/repos/ochrance-framework/modules/filesystem/shim:$LD_LIBRARY_PATH
```

**Problem:** `libnvme.h: No such file or directory`

**Solution:** Install the libnvme development package:

```bash
# Fedora
sudo dnf install libnvme-devel

# Ubuntu/Debian
sudo apt install libnvme-dev

# Arch
sudo pacman -S libnvme
```

### 9.3 ECHIDNA Backend Issues

**Problem:** `Idris2 type-check failed for generated proof`

**Solution:** This is expected for some neural candidates. The verification
loop will try up to 16 candidates. If all fail:

1. Check the proof goal is well-typed by compiling it separately.
2. Check that the context (available hypotheses) is complete.
3. Fall back to symbolic proof search (slower but more reliable).
4. Report the goal to VeriSimDB as a "hard" goal for future training.

### 9.4 Neural Synthesis Issues

**Problem:** `CUDA out of memory` during training

**Solution:** Reduce batch size or model dimensions:

```julia
config = ModelConfig(
    d_model = 256,         # reduced from 512
    dim_feedforward = 1024, # reduced from 2048
)
```

Or use gradient checkpointing:

```julia
Flux.train!(loss, params, opt; cb = Flux.throttle(gc, 60))
```

**Problem:** `Low synthesis success rate (< 50%)`

**Solution:**

1. Increase training data (more proof samples from symbolic search).
2. Use data augmentation (proof term transformations).
3. Increase beam width (try 32 or 64 instead of 16).
4. Check that the tokeniser vocabulary covers Ochrance-specific identifiers.
5. Fine-tune on domain-specific proofs (filesystem properties only).

---

## Appendix A: Weekly Milestone Summary

| Week | Phase | Milestone | Key Deliverable |
|------|-------|-----------|-----------------|
| 1 | P1 | A2ML Tokeniser | `Ochrance.A2ML.Types` module |
| 2 | P1 | A2ML Parser | `Ochrance.A2ML.Parser` module |
| 3 | P1 | A2ML Serialiser + Round-trip | Property-based tests passing |
| 4 | P1 | VerifiedSubsystem interface | `Ochrance.Core` module |
| 5 | P1 | VerifiedState + Hash types | `Ochrance.State`, `Ochrance.Hash` modules |
| 6 | P1 | Ephapax + Policy | `Ochrance.Ephapax`, `Ochrance.Policy` modules |
| 7 | P1 | C shims | `libochrance_shim.so` built and tested |
| 8 | P1 | FFI bindings | `Ochrance.Filesystem.NVMe` module |
| 9 | P1 | Merkle tree construction | `Ochrance.Merkle` with proofs |
| 10 | P1 | Filesystem module | `Ochrance.Filesystem.Module` complete |
| 11 | P1 | TUI framework | `Ochrance.TUI.Main` with q/p/z |
| 12 | P1 | Telemetry + integration tests | JSON-lines, OTel, end-to-end passing |
| 13 | P2 | Idris2 AST | `ast.rs` complete |
| 14 | P2 | Code generator | `codegen.rs` generating valid Idris2 |
| 15 | P2 | Proof templates | Common patterns as templates |
| 16 | P2 | Proof search strategy | ECHIDNA tactic engine extended |
| 17 | P2 | VeriSimDB integration | Proof caching operational |
| 18 | P2 | Ochrance-ECHIDNA bridge | End-to-end proof request working |
| 19 | P3 | Corpus extraction | Training data from Idris2 stdlib |
| 20 | P3 | Feature engineering | Proof term features computed |
| 21 | P3 | Data augmentation | 3x corpus via transformations |
| 22 | P3 | Model architecture | Transformer built in Flux.jl |
| 23 | P3 | Training pipeline | Model training on GPU |
| 24 | P3 | Beam search decoding | Candidate generation working |
| 25 | P3 | Verification loop | Neural + Idris2 type-checker |
| 26 | P3 | Synthesis benchmarks | Performance metrics recorded |
| 27 | P4 | Security audit | C shim audit report |
| 28 | P4 | Fuzzing campaign | AFL++ findings triaged |
| 29 | P4 | Performance optimisation | Parallel Merkle tree |
| 30 | P4 | Evaluation: correctness | 100% corruption detection |
| 31 | P4 | Evaluation: performance | Benchmark results tabulated |
| 32 | P4 | Evaluation: neural quality | Synthesis metrics recorded |
| 33 | P4 | Thesis: intro + background | Chapters 1-2 drafted |
| 34 | P4 | Thesis: architecture + impl | Chapters 3-4 drafted |
| 35 | P4 | Thesis: evaluation + discussion | Chapters 5-6 drafted |
| 36 | P4 | Thesis: revision | Complete draft reviewed |
| 37 | P4 | Thesis: final edits | Submission-ready |
| 38 | P4 | Submission + release | Thesis submitted, code released |

---

## Appendix B: Idris2 Package Files

### ochrance-core.ipkg

```ipkg
-- src/core/ochrance-core.ipkg
package ochrance-core
version = 0.1.0
authors = "Jonathan D.A. Jewell"
brief = "Ochrance framework core: VerifiedSubsystem, Merkle, A2ML, Policy"

depends = base
        , contrib

sourcedir = "."

modules = Ochrance.Core
        , Ochrance.State
        , Ochrance.Hash
        , Ochrance.Merkle
        , Ochrance.Ephapax
        , Ochrance.Policy
        , Ochrance.A2ML.Types
        , Ochrance.A2ML.Parser
        , Ochrance.A2ML.Serialiser
        , Ochrance.A2ML.Validate
```

### ochrance-filesystem.ipkg

```ipkg
-- modules/filesystem/ochrance-filesystem.ipkg
package ochrance-filesystem
version = 0.1.0
authors = "Jonathan D.A. Jewell"
brief = "Ochrance filesystem module: NVMe verification, repair, snapshots"

depends = base
        , ochrance-core

sourcedir = "."

modules = Ochrance.Filesystem.Module
        , Ochrance.Filesystem.NVMe
        , Ochrance.Filesystem.Smart
        , Ochrance.Filesystem.Snapshot
        , Ochrance.Filesystem.Repair

opts = "--cg chez"
libs = ochrance_shim
```
