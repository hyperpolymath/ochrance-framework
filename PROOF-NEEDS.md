# PROOF-NEEDS.md — ochrance-framework

## Current State

- **src/abi/*.idr**: NO
- **Dangerous patterns**: 0
- **LOC**: ~2,400
- **ABI layer**: Missing. Has `ffi/c/nvme_shim.h` (C header for NVMe)

## What Needs Proving

| Component | What | Why |
|-----------|------|-----|
| NVMe shim safety | C FFI shim does not corrupt memory or cause UB | Hardware-facing code; bugs cause data loss or system crash |
| Quantum-safe crypto (Exhibit B) | Post-quantum cryptographic operations are correct | Cryptographic correctness is non-negotiable |
| Ethical use enforcement (Exhibit A) | Policy enforcement logic is sound | Ethical guardrails must not have bypass paths |

## Recommended Prover

**Idris2** for ABI layer (create `src/abi/`). **Frama-C** or **CBMC** for the C NVMe shim verification. The quantum-safe crypto may need **Coq** with existing cryptographic proof libraries.

## Priority

**MEDIUM** — Framework-level code that other components depend on. The NVMe shim is the highest-risk component (C code touching hardware). Missing ABI layer entirely.
