<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Ochránce — System Architecture & Completion Dashboard

## System Architecture

```
                    ┌─────────────────────────────────┐
                    │         USER / OPERATOR          │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  L5: TUI / TELEMETRY HUB        │
                    │  q/p/z Semantic Diagnostics      │
                    │  [Progress Bars] [Health] [Diff] │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  L4: POLICY GOVERNOR             │
                    │  System Integrity Constraints    │
                    │  (signed binaries, auth, access) │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  L3: ATOMIC STATE / EPHAPAX      │
                    │  Linear Type Repair              │
                    │  <Zstd Snapshot> <CoW> <Rollback>│
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  L2: MERKLE ROOT + A2ML          │
                    │  Idris2 VerifiedState Proofs     │
                    │  (Hash-Tree) (Content-Addressed) │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  L1: BLOCK OBSERVER              │
                    │  C Shims (~200 lines)            │
                    │  nvme_read_smart/block/write     │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  L0: HARDWARE ROOT               │
                    │  [TPM/Secure Boot] [RISC-V PMP]  │
                    │  [NVMe SSD] [CPU Ring-0/M-Mode]  │
                    └─────────────────────────────────┘

     ┌──────────────────────────────────────────────────────┐
     │              ECHIDNA (Neural Proof Synthesis)         │
     │  ┌──────────┐  ┌───────────┐  ┌──────────────────┐  │
     │  │ 12 Provers│  │ Idris2    │  │ Julia ML         │  │
     │  │ (existing)│  │ (13th NEW)│  │ (Transformer)    │  │
     │  └──────────┘  └─────┬─────┘  └────────┬─────────┘  │
     │                      │                  │             │
     │              ┌───────▼──────────────────▼──────┐     │
     │              │  Neural Synthesizer → Verifier   │     │
     │              │  Generate candidates → Check     │     │
     │              └─────────────────────────────────┘     │
     └──────────────────────────────────────────────────────┘

     MODULES (VerifiedSubsystem interface):
     ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
     │Filesystem│ │  Memory  │ │ Network  │ │  Crypto  │
     │Idris2 + C│ │Idris2+Rs │ │Idris2+BPF│ │ → HACL*  │
     │ ACTIVE   │ │ FUTURE   │ │ FUTURE   │ │ FUTURE   │
     └──────────┘ └──────────┘ └──────────┘ └──────────┘
```

## Completion Dashboard

### Overall Progress

```
Ochránce Framework     [██░░░░░░░░]  10%
```

### Layer Implementation

```
L0: Hardware Root      [░░░░░░░░░░]   0%  (hardware, no code needed)
L1: Block Observer     [█░░░░░░░░░]  10%  (C shim scaffolding)
L2: Merkle + A2ML      [██░░░░░░░░]  20%  (types + spec defined)
L3: Atomic State       [░░░░░░░░░░]   0%  (not started)
L4: Policy Governor    [█░░░░░░░░░]  10%  (policy spec written)
L5: TUI / Telemetry    [░░░░░░░░░░]   0%  (not started)
```

### A2ML Parser

```
Specification          [████████░░]  80%
Types / AST            [███░░░░░░░]  30%  (stub)
Lexer                  [██░░░░░░░░]  20%  (stub, needs totality proof)
Parser                 [██░░░░░░░░]  20%  (stub, needs totality proof)
Validator              [█░░░░░░░░░]  10%  (stub)
Serializer             [█░░░░░░░░░]  10%  (stub)
Security Hardening     [░░░░░░░░░░]   0%
Property Tests         [░░░░░░░░░░]   0%
```

### Module Status

```
Filesystem (thesis)    [██░░░░░░░░]  20%  (types defined, stubs)
Memory (future)        [░░░░░░░░░░]   0%  (design only)
Network (future)       [░░░░░░░░░░]   0%  (design only)
Crypto (future)        [░░░░░░░░░░]   0%  (design only)
```

### ECHIDNA Integration

```
Idris2 Backend Design  [████░░░░░░]  40%  (spec in white paper)
Rust Prover Impl       [░░░░░░░░░░]   0%
FFI Bridge             [░░░░░░░░░░]   0%
Neural Corpus          [░░░░░░░░░░]   0%
Model Training         [░░░░░░░░░░]   0%
```

### Documentation

```
Architecture           [████████░░]  80%
White Paper            [███████░░░]  70%
Implementation Guide   [███████░░░]  70%
A2ML Spec              [████████░░]  80%
FFI Contract           [██████░░░░]  60%
L4 Policies            [████████░░]  80%
TOPOLOGY.md            [██████████] 100%
```

### Research

```
Thesis Outline         [████░░░░░░]  40%
ICFP Paper Draft       [░░░░░░░░░░]   0%
Benchmarks             [░░░░░░░░░░]   0%
Case Studies           [░░░░░░░░░░]   0%
```

## Key Dependencies

```
Critical Path:
  A2ML Parser (total) ──→ Merkle Verification ──→ Filesystem Module
       │                                               │
       ▼                                               ▼
  Echidna Idris2 Backend ──→ Neural Synthesis ──→ Thesis Evaluation
```

| Dependency | Status | Impact |
|-----------|--------|--------|
| Idris2 0.7.0+ | Available | Core compiler |
| libnvme | Available | NVMe syscalls |
| ECHIDNA platform | Exists (hyperpolymath) | Neural proof synthesis |
| BLAKE3 library | Available | Hash algorithm |
| OSTree | Available (Kinoite) | Deployment target |
| HACL* | Available | Verified crypto (future) |
