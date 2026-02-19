<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Ochrance Framework -- L0-L5 Architecture Specification

> **Repository:** `ochrance-framework`
> **Prose name:** Ochrance (with diacritic)
> **Code identifiers:** `Ochrance` (no diacritic)
> **Version:** 1.0.0-draft
> **Last updated:** 2026-02-19

## Overview

Ochrance is a neurosymbolic filesystem verification framework built around
a layered architecture (L0 through L5). Each layer has a single, well-defined
responsibility. Higher layers depend on lower layers but never vice versa.

The framework is designed as a **framework-first** system: the core defines
the `VerifiedSubsystem` interface, and modules (filesystem, memory, network,
crypto) implement that interface independently. The filesystem module serves
as the reference implementation and thesis scope; the remaining modules are
future extensions.

```
  L5  TUI / Telemetry         (user-facing diagnostics)
  L4  Policy Governor          (system integrity constraints)
  L3  Atomic State / Ephapax   (linear-type repair, CoW snapshots)
  L2  Merkle Root + A2ML       (Idris2 proofs, VerifiedState witness)
  L1  Block Observer           (thin C shims, NVMe SMART)
  L0  Hardware Root            (TPM, Secure Boot, PMP)
```

---

## L0: Hardware Root

**Purpose:** Provide the hardware-anchored root of trust from which all higher
layers derive their integrity guarantees.

**Components:**

| Component | Role |
|-----------|------|
| TPM 2.0 | Platform Configuration Register (PCR) measurements, sealed storage, attestation |
| UEFI Secure Boot | Verified boot chain from firmware through bootloader to kernel |
| PMP (Physical Memory Protection) | Hardware memory isolation on RISC-V targets |
| Hardware RNG | Entropy source for nonces, key generation |

**Invariants:**

- L0 is read-only from the perspective of software layers L1-L5.
- All L0 measurements are forwarded upward as opaque attestation blobs.
- Ochrance does not modify TPM state; it only reads PCR values and
  verifies quotes.
- If L0 is absent or unavailable (e.g., a VM without vTPM), Ochrance
  operates in **degraded mode** with a software-only root of trust and
  logs a warning.

**Interface to L1:**

```
tpm_read_pcr(index: Nat) -> Bytes
tpm_quote(pcr_mask: BitVec 24, nonce: Bytes) -> SignedQuote
secure_boot_state() -> BootState  -- Enabled | Disabled | SetupMode
```

---

## L1: Block Observer

**Purpose:** Provide a thin, deterministic interface between userspace and
block storage hardware. L1 is the only layer that performs I/O.

**Implementation language:** C (thin shims, approximately 200 lines total).

**Dependencies:** `libnvme` for NVMe SMART data and namespace management.

**Key functions (C shims):**

```c
// Read NVMe SMART/Health log (Log Page 02h)
// Returns: 0 on success, negative errno on failure
int nvme_read_smart(int fd, struct nvme_smart_log *smart);

// Read a single block from an NVMe namespace
// Caller provides aligned buffer; Idris2 verifies offset < device_blocks
int nvme_read_block(int fd, uint64_t lba, void *buf, size_t len);

// Write a single block to an NVMe namespace
// Idris2 verifies offset < device_blocks AND block content hash
int nvme_write_block(int fd, uint64_t lba, const void *buf, size_t len);
```

**Design rationale:**

The C shims are deliberately minimal -- "too dumb to break invariants."
All bounds checking, hash verification, and state management happen in
Idris2 at L2. The C layer exists solely because Idris2 cannot issue
`ioctl()` syscalls directly.

**NVMe SMART fields consumed:**

| Field | Use |
|-------|-----|
| `critical_warning` | Trigger L3 repair if non-zero |
| `temperature` | Telemetry (L5) |
| `available_spare` | Predictive wear-out alerting |
| `data_units_read` / `data_units_written` | I/O accounting |
| `media_errors` | Trigger L3 snapshot + repair |

**Invariants:**

- L1 never allocates heap memory. All buffers are provided by the caller.
- L1 never retries failed I/O. Retry policy belongs to L3.
- L1 returns raw bytes and error codes; interpretation is L2's responsibility.

---

## L2: Merkle Root + A2ML

**Purpose:** Construct and verify cryptographic proofs over filesystem state.
L2 is the "brain" of Ochrance -- it takes raw bytes from L1 and produces
formally verified state witnesses.

**Implementation language:** Idris2 (with `%foreign` calls to L1 C shims).

**Core type: `VerifiedState`**

```idris
-- A VerifiedState witness is a dependent pair:
-- the Merkle root hash, plus a proof that it was constructed
-- from a valid block sequence.
data VerifiedState : Type where
  MkVerified : (root : Hash algo)
            -> (proof : MerkleProof blocks root)
            -> (timestamp : Posix)
            -> VerifiedState
```

**Merkle tree construction:**

- Leaf nodes: SHA-256 hash of each 4096-byte block.
- Internal nodes: `H(left || right)` with domain separation tag.
- Root: single hash representing the entire verified filesystem state.
- Algorithm agility: SHA-256 (default), SHA3-256, BLAKE3 supported via
  the `HashAlgo` type family.

**A2ML (Attestation and Audit Markup Language):**

L2 serialises `VerifiedState` into A2ML documents for persistent storage
and cross-system attestation. See `docs/A2ML-SPEC.md` for the full
specification.

**Idris2 proof obligations at L2:**

1. **Completeness:** Every block in the filesystem has a corresponding leaf
   in the Merkle tree (no gaps).
2. **Consistency:** The tree is well-formed (balanced, correctly hashed).
3. **Freshness:** The timestamp monotonically increases across snapshots.
4. **Inclusion:** Any block can be verified against the root with a
   logarithmic-sized proof path.

**Interface to L3:**

```idris
-- Verify current state and return a witness (or an error)
verifyFilesystem : (dev : DeviceHandle)
               -> IO (Either VerificationError VerifiedState)

-- Verify a single block against a known root
verifyBlock : (root : Hash algo)
           -> (path : MerklePath)
           -> (block : Block)
           -> Dec (InTree root path block)
```

---

## L3: Atomic State / Ephapax

**Purpose:** Provide atomic, exactly-once state transitions with automatic
rollback on failure. L3 is the "hands" of Ochrance -- it performs repairs.

**Key concepts:**

| Concept | Description |
|---------|-------------|
| Ephapax (Greek: "once") | A linear-typed token consumed exactly once per state transition. Prevents double-apply and missed-apply bugs at compile time. |
| CoW Snapshots | Copy-on-Write snapshots taken before any repair operation. Rollback is always possible. |
| Repair Actions | A closed set of operations: `RestoreBlock`, `RewriteMetadata`, `QuarantineFile`, `RebuildIndex`. |

**Linear type enforcement:**

```idris
-- An Ephapax token is created when L2 detects corruption.
-- It MUST be consumed by exactly one repair action.
-- The linear type system prevents:
--   (a) ignoring the token (corruption goes unrepaired)
--   (b) using it twice (double repair)
data Ephapax : RepairAction -> Type where
  MkEphapax : (1 _ : RepairAction) -> Ephapax action

-- Consume the token by performing the repair
applyRepair : (1 token : Ephapax action)
           -> (snapshot : SnapshotHandle)
           -> IO RepairResult
```

**Snapshot lifecycle:**

1. L2 reports corruption, producing an `Ephapax` token.
2. L3 creates a CoW snapshot of the affected region.
3. L3 applies the repair action, consuming the token.
4. If repair succeeds, the snapshot is marked as "historical."
5. If repair fails, L3 rolls back from the snapshot and escalates to L4.

**Invariants:**

- No repair action is applied without a prior snapshot.
- The `Ephapax` token ensures exactly-once semantics at the type level.
- All state transitions are logged to the A2ML audit trail (L2).

---

## L4: Policy Governor

**Purpose:** Enforce **system integrity constraints** over the verified state.
L4 decides whether a given filesystem state is *acceptable* according to
declarative policy rules.

**CRITICAL DISTINCTION:** L4 is for **system integrity only**. It governs
questions like "Is this binary signed?" and "Has this config file been
tampered with?" It does **NOT** govern content-level concerns like spelling,
code style, or business logic. See `docs/L4-POLICIES.md` for valid examples
and anti-patterns.

**Policy language:**

Policies are expressed as Idris2 predicates over `VerifiedState`:

```idris
-- A Policy is a decidable predicate over VerifiedState.
-- If it returns `Yes prf`, the state satisfies the policy.
-- If it returns `No contra`, the state violates the policy,
-- and `contra` is a machine-checkable proof of the violation.
Policy : Type
Policy = (s : VerifiedState) -> Dec (Satisfies s)
```

**Policy categories (all valid):**

- Binary signature verification
- Kernel module signing enforcement
- Configuration file immutability
- Permission mask constraints
- Boot chain integrity
- Certificate pinning
- Filesystem quota enforcement
- Audit log append-only guarantee
- Mount option validation
- SUID/SGID restriction

**Evaluation model:**

1. L2 produces a `VerifiedState`.
2. L4 evaluates all active policies against the state.
3. Policies that fail produce `PolicyViolation` values.
4. Violations are reported to L5 (TUI/Telemetry) and optionally trigger
   L3 repair actions.

---

## L5: TUI / Telemetry

**Purpose:** Present verified state information to human operators via a
terminal user interface, and emit structured telemetry for monitoring systems.

**Semantic diagnostics (q/p/z model):**

| Code | Meaning | Severity |
|------|---------|----------|
| `q` (quiescent) | System is verified and healthy | Info |
| `p` (perturbation) | Anomaly detected, investigation needed | Warning |
| `z` (zero-trust) | Integrity violation confirmed, repair initiated | Critical |

**TUI features:**

- Real-time Merkle tree visualisation (collapsed by default, expandable).
- Block-level diff view when corruption is detected.
- Policy evaluation dashboard (pass/fail/skip per policy).
- NVMe SMART health summary (temperature, wear, errors).
- Repair history timeline with snapshot links.

**Telemetry output formats:**

- JSON lines (structured logging, compatible with `jq` pipelines).
- OpenTelemetry spans (for distributed tracing integration).
- A2ML attestation documents (for cross-system verification).

**Invariants:**

- L5 is read-only with respect to system state. It never modifies L0-L4.
- All telemetry emission is non-blocking; a slow consumer cannot stall
  verification.
- TUI rendering failures are isolated and never affect L2/L3 operations.

---

## Framework-First: The VerifiedSubsystem Interface

Ochrance is not a monolithic filesystem tool. It is a **framework** that
defines a common interface (`VerifiedSubsystem`) which any system module
can implement.

```idris
-- The VerifiedSubsystem interface.
-- Any module implementing this interface gets:
--   - Merkle tree construction and verification (L2)
--   - Atomic repair with Ephapax tokens (L3)
--   - Policy evaluation (L4)
--   - TUI/Telemetry integration (L5)
interface VerifiedSubsystem (m : Type -> Type) where
  -- Enumerate the blocks/units managed by this subsystem
  enumerateUnits : m (List UnitId)

  -- Read a single unit (block, page, packet, etc.)
  readUnit : UnitId -> m (Either ReadError RawBytes)

  -- Write a single unit (used during repair)
  writeUnit : UnitId -> RawBytes -> m (Either WriteError ())

  -- Hash a unit for Merkle tree construction
  hashUnit : RawBytes -> Hash algo

  -- Subsystem-specific health check
  healthCheck : m HealthStatus
```

### Modules

#### Filesystem Module (Reference Implementation)

- **Status:** Active development (thesis scope).
- **Languages:** Idris2 (proofs, state management) + inline C (NVMe shims via `%foreign`).
- **Scope:** NVMe block-level verification, Merkle tree over filesystem blocks,
  A2ML attestation, Ephapax repair.
- **Location:** `modules/filesystem/`

#### Memory Module (Future)

- **Status:** Planned.
- **Languages:** Idris2 (proofs) + Rust (memory introspection, `/proc/self/maps`).
- **Scope:** Verified memory page integrity, stack canary verification,
  heap metadata consistency.
- **Location:** `modules/memory/`

#### Network Module (Future)

- **Status:** Planned.
- **Languages:** Idris2 (proofs) + eBPF (packet-level observation).
- **Scope:** Network flow verification, TLS certificate chain validation,
  DNS response integrity.
- **Location:** `modules/network/`

#### Crypto Module (Future)

- **Status:** Planned.
- **Languages:** Idris2 (proofs) + linkage to HACL* (verified crypto library).
- **Scope:** Verified cryptographic operations, key lifecycle management,
  algorithm agility proofs.
- **Location:** `modules/crypto/`

---

## Layer Dependency Rules

```
  L5 depends on: L4, L2, L1 (telemetry data)
  L4 depends on: L2 (VerifiedState)
  L3 depends on: L2 (corruption reports), L1 (I/O for repair)
  L2 depends on: L1 (raw block data)
  L1 depends on: L0 (hardware interface)
  L0 depends on: nothing (hardware root)
```

**Prohibited dependencies:**

- L1 must NEVER depend on L2 or higher (no "smart" I/O layer).
- L4 must NEVER depend on L3 (policy does not know about repair).
- L5 must NEVER modify state in L0-L4 (read-only observer).

---

## Cross-References

| Document | Relevance |
|----------|-----------|
| `docs/A2ML-SPEC.md` | Full A2ML grammar and semantics (L2 output format) |
| `docs/FFI-CONTRACT.md` | Idris2-to-C FFI contract (L1/L2 boundary) |
| `docs/L4-POLICIES.md` | Valid L4 policy examples and anti-patterns |
| `docs/ROADMAP.md` | Implementation phases and timeline |
| `docs/WHITEPAPER.md` | Academic white paper with formal treatment |
| `docs/IMPLEMENTATION-GUIDE.md` | Week-by-week development plan |
| `TOPOLOGY.md` | Visual architecture diagram and completion dashboard |
