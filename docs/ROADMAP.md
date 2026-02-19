<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Ochrance Framework -- Implementation Roadmap

> **Version:** 1.0.0-draft
> **Last updated:** 2026-02-19
> **Author:** Jonathan D.A. Jewell, The Open University
> **Thesis context:** MSc Computer Science, The Open University

## Overview

This roadmap defines the four-phase implementation plan for the Ochrance
neurosymbolic filesystem verification framework and its integration with
the ECHIDNA platform. The total timeline spans approximately 38 weeks
(Q1-Q4 2026).

---

## Phase 1: Ochrance Core (Q1 2026, 12 weeks)

**Objective:** Build the foundational framework: A2ML parser, VerifiedSubsystem
interface, and the filesystem module as the reference implementation.

### Milestone 1.1: A2ML Parser and Serialiser (Weeks 1-3)

| Deliverable | Language | Status |
|-------------|----------|--------|
| EBNF grammar formalisation | Specification | Planned |
| A2ML tokeniser | Idris2 | Planned |
| A2ML parser (recursive descent) | Idris2 | Planned |
| A2ML serialiser (pretty-printer) | Idris2 | Planned |
| Round-trip property tests | Idris2 (Hedgehog) | Planned |
| Parser error recovery and diagnostics | Idris2 | Planned |

**Acceptance criteria:**
- `parse (serialise doc) == Right doc` for all valid documents.
- Parser rejects all documents violating the EBNF grammar with informative
  error messages (line number, expected token).
- Fuzz testing with 10,000+ random inputs produces no crashes.

### Milestone 1.2: VerifiedSubsystem Interface (Weeks 3-5)

| Deliverable | Language | Status |
|-------------|----------|--------|
| `VerifiedSubsystem` interface definition | Idris2 | Planned |
| `VerifiedState` type with Merkle root | Idris2 | Planned |
| `Ephapax` linear-type tokens | Idris2 | Planned |
| Hash algorithm agility (`HashAlgo` type family) | Idris2 | Planned |
| Policy Governor (`Policy` type, composition) | Idris2 | Planned |
| Module registration mechanism | Idris2 | Planned |

**Acceptance criteria:**
- A minimal "dummy" module can implement `VerifiedSubsystem` and produce
  a `VerifiedState`.
- `Ephapax` tokens enforce exactly-once semantics (double-use is a compile
  error).
- Policies compose via `AllOf`, `AnyOf`, `Not`.

### Milestone 1.3: Filesystem Module (Weeks 5-10)

| Deliverable | Language | Status |
|-------------|----------|--------|
| C shims (`nvme_read_smart`, `nvme_read_block`, `nvme_write_block`) | C | Planned |
| `libochrance_shim.so` build system | Makefile | Planned |
| Idris2 FFI bindings (`%foreign`) | Idris2 | Planned |
| Merkle tree construction from block hashes | Idris2 | Planned |
| Merkle inclusion proof generation and verification | Idris2 | Planned |
| Completeness proof (all blocks covered) | Idris2 | Planned |
| Consistency proof (well-formed tree) | Idris2 | Planned |
| NVMe SMART data parsing and health assessment | Idris2 | Planned |
| CoW snapshot creation (via `btrfs` subvolume or LVM snapshot) | Idris2 + C | Planned |
| Repair actions: `RestoreBlock`, `RewriteMetadata`, `QuarantineFile` | Idris2 | Planned |
| A2ML attestation document generation | Idris2 | Planned |

**Acceptance criteria:**
- Full verification of a 1 GB test filesystem completes in under 10 seconds.
- Injected corruption (flipped bit in a block) is detected with 100% reliability.
- Repair from CoW snapshot restores the original block content.
- Generated A2ML document passes the A2ML parser round-trip test.

### Milestone 1.4: TUI and Telemetry (Weeks 10-12)

| Deliverable | Language | Status |
|-------------|----------|--------|
| Terminal UI (Merkle tree view, policy dashboard) | Idris2 or Rust | Planned |
| q/p/z semantic diagnostics | Idris2 | Planned |
| JSON-lines structured logging | Idris2 | Planned |
| OpenTelemetry span emission | Idris2 | Planned |
| Integration test suite (end-to-end) | Idris2 | Planned |

**Acceptance criteria:**
- TUI displays real-time verification status without blocking L2/L3.
- Diagnostic codes (q, p, z) correctly classify system state.
- JSON logs are parseable by `jq` and compatible with log aggregators.

---

## Phase 2: ECHIDNA + Idris2 Backend (Q2 2026, 6 weeks)

**Objective:** Create an Idris2 prover backend for the ECHIDNA platform,
enabling ECHIDNA to generate and verify Idris2 proofs for filesystem
properties.

### Milestone 2.1: Idris2 Code Generation (Weeks 13-15)

| Deliverable | Language | Status |
|-------------|----------|--------|
| AST representation of Idris2 terms | Rust | Planned |
| Code generator: AST to Idris2 source | Rust | Planned |
| Template library for common proof patterns | Rust + Idris2 | Planned |
| Round-trip test: generate, compile, verify | Rust + Idris2 | Planned |

**Acceptance criteria:**
- Generated Idris2 code compiles without errors on Idris2 0.7.0+.
- 95% of generated proofs type-check on first attempt.
- Code generation for a typical filesystem property takes under 1 second.

### Milestone 2.2: Proof Search Integration (Weeks 15-17)

| Deliverable | Language | Status |
|-------------|----------|--------|
| ECHIDNA proof search strategy for Idris2 | Rust | Planned |
| Tactic mapping (ECHIDNA tactics to Idris2 elaboration) | Rust | Planned |
| Proof caching and incremental verification | Rust | Planned |
| VeriSimDB integration for proof similarity search | Rust + Julia | Planned |

**Acceptance criteria:**
- ECHIDNA can synthesise a Merkle tree completeness proof from a property
  specification.
- Proof search terminates within 30 seconds for properties over trees
  with up to 2^18 leaves.
- VeriSimDB cache hit rate exceeds 60% for common property patterns.

### Milestone 2.3: Ochrance-ECHIDNA Bridge (Week 18)

| Deliverable | Language | Status |
|-------------|----------|--------|
| API bridge: Ochrance L2 to ECHIDNA prover | Idris2 + Rust | Planned |
| Proof witness serialisation (Idris2 to A2ML) | Idris2 | Planned |
| End-to-end test: verify filesystem, generate proof, embed in A2ML | All | Planned |

**Acceptance criteria:**
- Ochrance can request a proof from ECHIDNA and embed the result in an
  A2ML attestation document.
- The round-trip (request, generate, embed, verify) completes in under
  5 seconds for standard properties.

---

## Phase 3: Neural Synthesis (Q3 2026, 8 weeks)

**Objective:** Integrate neural proof synthesis into the ECHIDNA-Ochrance
pipeline, enabling the system to learn from past proofs and synthesise
new ones.

### Milestone 3.1: Training Data Pipeline (Weeks 19-22)

| Deliverable | Language | Status |
|-------------|----------|--------|
| Proof corpus extraction from Idris2 standard library | Julia | Planned |
| Proof corpus extraction from verified filesystem properties | Julia | Planned |
| Feature engineering for proof terms | Julia | Planned |
| Training data format specification | Julia | Planned |
| Data augmentation (proof term transformations) | Julia | Planned |

### Milestone 3.2: Neural Proof Model (Weeks 22-24)

| Deliverable | Language | Status |
|-------------|----------|--------|
| Transformer architecture for proof synthesis | Julia (Flux.jl) | Planned |
| Training pipeline (multi-GPU support) | Julia | Planned |
| Beam search decoding for proof candidates | Julia | Planned |
| Confidence scoring and calibration | Julia | Planned |
| Integration with ECHIDNA proof search | Julia + Rust | Planned |

### Milestone 3.3: Verification Loop (Weeks 25-26)

| Deliverable | Language | Status |
|-------------|----------|--------|
| Neural candidate generation | Julia | Planned |
| Idris2 type-checker verification of candidates | Idris2 | Planned |
| Feedback loop: failed candidates improve search | Julia + Rust | Planned |
| Performance benchmarking against pure symbolic search | Julia | Planned |

**Phase 3 acceptance criteria:**
- Neural synthesis produces valid proofs for 70%+ of standard filesystem
  properties.
- Average synthesis time is under 5 seconds.
- Verified proofs are indistinguishable from hand-written proofs in
  correctness (100% type-check rate after filtering).

---

## Phase 4: Production and Thesis (Q4 2026, 12 weeks)

**Objective:** Harden the system for production use, write the MSc thesis,
and prepare for publication.

### Milestone 4.1: Production Hardening (Weeks 27-32)

| Deliverable | Language | Status |
|-------------|----------|--------|
| Security audit of C shims (Frama-C or manual) | C | Planned |
| Fuzzing campaign (AFL++, libFuzzer) | C + Idris2 | Planned |
| Performance optimisation (parallel Merkle tree) | Idris2 | Planned |
| Memory usage profiling and optimisation | Idris2 + C | Planned |
| Containerised deployment (Podman, Chainguard base) | Containerfile | Planned |
| CI/CD pipeline (GitHub Actions, panic-attack, echidna) | YAML | Planned |
| Documentation: user guide, API reference | Markdown | Planned |

### Milestone 4.2: Evaluation (Weeks 30-34)

| Deliverable | Status |
|-------------|--------|
| Correctness evaluation: 100% detection of injected corruption | Planned |
| Performance evaluation: verification time vs. filesystem size | Planned |
| Neural synthesis quality: precision, recall, synthesis time | Planned |
| Case studies: NVMe wear-out prediction, boot chain verification | Planned |
| Comparison with related work (AIDE, OSSEC, dm-verity, fs-verity) | Planned |

### Milestone 4.3: Thesis Writing (Weeks 32-38)

| Chapter | Status |
|---------|--------|
| Introduction and motivation | Planned |
| Background and related work | Planned |
| Architecture (Ochrance L0-L5) | Planned |
| Implementation (framework, filesystem module, ECHIDNA integration) | Planned |
| Evaluation (correctness, performance, neural synthesis) | Planned |
| Discussion and future work | Planned |
| Conclusion | Planned |

### Milestone 4.4: Publication and Release (Weeks 36-38)

| Deliverable | Status |
|-------------|--------|
| MSc thesis submission to The Open University | Planned |
| Conference paper submission (target: USENIX Security or IEEE S&P) | Planned |
| Open-source release of Ochrance framework (PMPL-1.0-or-later) | Planned |
| Blog post: "Building a Neurosymbolic Filesystem Verifier" | Planned |

---

## Dependencies and Risks

### External Dependencies

| Dependency | Version | Risk |
|------------|---------|------|
| Idris2 | >= 0.7.0 | Low (stable release) |
| libnvme | >= 1.0 | Low (widely packaged) |
| ECHIDNA platform | Current | Medium (internal project) |
| Julia | >= 1.10 | Low (stable release) |
| Flux.jl | >= 0.14 | Low (mature ML framework) |

### Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Idris2 compiler bugs | High | Medium | Pin compiler version, report bugs upstream |
| NVMe hardware access requires root | Medium | High | Use `nvmet` loopback for testing, capability-based access for production |
| Neural synthesis quality below threshold | Medium | Medium | Fall back to pure symbolic search; neural is an enhancement, not a requirement |
| Thesis timeline pressure | High | Medium | Filesystem module alone is sufficient for thesis; ECHIDNA integration is bonus |
| C shim security vulnerability | High | Low | Keep shims minimal (~200 lines), fuzz extensively, consider Frama-C verification |

---

## Timeline Summary

```
2026
 Q1  ████████████████████████████████████████████████  Phase 1: Ochrance Core
      Jan         Feb         Mar
      M1.1(A2ML)  M1.2(Interface) M1.3(Filesystem)  M1.4(TUI)

 Q2  ████████████████████████                          Phase 2: ECHIDNA Backend
      Apr         May
      M2.1(CodeGen) M2.2(ProofSearch) M2.3(Bridge)

 Q3  ████████████████████████████████                  Phase 3: Neural Synthesis
      Jul         Aug
      M3.1(Data)  M3.2(Model)  M3.3(VerifyLoop)

 Q4  ████████████████████████████████████████████████  Phase 4: Production+Thesis
      Oct         Nov         Dec
      M4.1(Harden)  M4.2(Eval)  M4.3(Thesis)  M4.4(Publish)
```

---

## Cross-References

| Document | Relevance |
|----------|-----------|
| `docs/ARCHITECTURE.md` | L0-L5 architecture that this roadmap implements |
| `docs/WHITEPAPER.md` | Academic treatment and formal specification |
| `docs/IMPLEMENTATION-GUIDE.md` | Detailed week-by-week development plan |
| `docs/FFI-CONTRACT.md` | C shim contract (Milestone 1.3) |
| `docs/A2ML-SPEC.md` | A2ML specification (Milestone 1.1) |
