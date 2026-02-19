<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Neurosymbolic Filesystem Verification: Integrating ECHIDNA with Ochrance

**Author:** Jonathan D.A. Jewell, The Open University

**Contact:** jonathan.jewell@open.ac.uk

**Date:** February 2026

**Status:** Working Draft

---

## Abstract

We present a neurosymbolic approach to filesystem integrity verification
that combines dependent type theory, Merkle tree cryptography, and neural
proof synthesis. The Ochrance framework provides a layered architecture
(L0-L5) for continuous filesystem verification, anchored in hardware roots
of trust and expressed through formally verified Idris2 proofs. The ECHIDNA
(Extensible Calculus for Heuristic Investigation and Deductive Navigational
Analysis) platform provides neural-guided proof search that dramatically
reduces the manual proof burden. Together, they enable a system where
filesystem integrity properties are not merely checked at runtime but are
*proven correct* with machine-checkable certificates.

We describe the architecture, formalisation, implementation strategy, and
evaluation plan for this integrated system. The filesystem module serves
as the reference implementation, with memory, network, and cryptographic
modules planned as future extensions. Our approach addresses a gap in the
existing filesystem verification landscape: current tools (AIDE, OSSEC,
dm-verity, fs-verity) detect changes but do not provide *proofs of
correctness* that can be independently verified.

**Keywords:** neurosymbolic verification, dependent types, Idris2, Merkle
trees, filesystem integrity, proof synthesis, formal methods, NVMe, SMART

---

## 1. Introduction

### 1.1 The Problem

Modern operating systems trust their filesystems implicitly. When a binary
is loaded for execution, the kernel assumes it has not been tampered with.
When a configuration file is read, the application assumes it contains
valid, authorised content. When audit logs are consulted after an incident,
investigators assume they have not been modified by an attacker covering
their tracks.

These assumptions are frequently violated. Rootkits modify system binaries.
Attackers alter configuration files to weaken security. Sophisticated
adversaries tamper with audit logs to erase evidence. Even non-malicious
events -- hardware failures, cosmic rays, firmware bugs -- can corrupt
filesystem data silently.

Existing integrity verification tools address this partially:

- **AIDE/OSSEC:** File-level hash databases, checked periodically. No formal
  proofs; no real-time verification; database itself can be compromised.
- **dm-verity:** Block-level Merkle tree verification for read-only partitions.
  Effective but limited to immutable filesystems; no repair capability.
- **fs-verity:** File-level authentication built into the kernel. Per-file
  only; no system-wide integrity guarantees.
- **IMA/EVM:** Kernel-level integrity measurement. Runtime overhead
  concerns; complex policy configuration; no formal correctness proofs.

None of these tools provide *machine-checkable proofs of correctness*.
They report "no changes detected" or "hash mismatch found," but they
cannot produce a certificate that an independent verifier can check without
trusting the tool itself.

### 1.2 Our Approach

Ochrance addresses this gap by combining three technologies:

1. **Dependent type theory (Idris2):** Filesystem integrity properties are
   expressed as types. A verified state is a *value* of a type that can
   only be constructed if the property holds. The Idris2 type checker
   serves as the proof verifier.

2. **Merkle tree cryptography:** The filesystem is reduced to a single
   hash (the Merkle root). Changes to any block are detectable in
   O(log n) time. The Merkle root is the foundation of the `VerifiedState`
   type.

3. **Neural proof synthesis (ECHIDNA):** Writing Idris2 proofs by hand
   is labour-intensive. ECHIDNA uses neural-guided proof search to
   synthesise proofs automatically, verified by the Idris2 type checker
   as a soundness guarantee.

### 1.3 Contributions

This paper makes the following contributions:

1. **The Ochrance framework:** A layered (L0-L5) architecture for
   filesystem verification with formally verified state management.

2. **A2ML:** A specification for Attestation and Audit Markup Language,
   enabling cross-system verification of integrity attestations.

3. **Ephapax tokens:** A linear-type mechanism for exactly-once repair
   operations, preventing both missed and duplicate repairs at compile time.

4. **ECHIDNA Idris2 backend:** An extension to the ECHIDNA platform that
   generates and verifies Idris2 proofs for filesystem properties.

5. **Neural proof synthesis for filesystem properties:** A neural model
   trained on verified proof corpora that synthesises proof candidates,
   verified by the Idris2 type checker.

6. **Evaluation:** Correctness, performance, and synthesis quality
   measurements on real NVMe hardware.

### 1.4 Paper Organisation

Section 2 provides background on the Ochrance framework, the ECHIDNA
platform, and the Idris2 language. Section 3 describes the integrated
architecture. Section 4 details the implementation strategy. Section 5
presents the evaluation plan. Sections 6-8 cover related work, risks,
and future directions. Section 9 concludes.

---

## 2. Background

### 2.1 The Ochrance Framework

Ochrance (Czech: protector, guardian; IPA: /ˈoxraːnt͡sɛ/) is a neurosymbolic
filesystem verification framework organised into six layers:

| Layer | Name | Responsibility |
|-------|------|----------------|
| L0 | Hardware Root | TPM 2.0, Secure Boot, hardware RNG |
| L1 | Block Observer | Thin C shims (~200 lines), NVMe SMART via libnvme |
| L2 | Merkle Root + A2ML | Idris2 proofs, VerifiedState witness, attestation documents |
| L3 | Atomic State / Ephapax | Linear-type repair tokens, CoW snapshots |
| L4 | Policy Governor | System integrity constraints (decidable predicates) |
| L5 | TUI / Telemetry | q/p/z semantic diagnostics, structured logging |

The framework is designed as a module system: the `VerifiedSubsystem`
interface defines the contract, and individual modules (filesystem, memory,
network, crypto) provide implementations. This paper focuses on the
filesystem module as the reference implementation and thesis scope.

Key design decisions:

- **Idris2 as the proof language:** Idris2's dependent types and linear
  types provide the expressiveness needed for both correctness proofs
  (L2) and resource management (L3). Unlike Coq or Lean, Idris2 is
  designed for practical programming with effects.

- **C as the I/O layer:** The C shims at L1 are deliberately minimal.
  They perform I/O via `ioctl()` and nothing else. All intelligence resides
  in Idris2. The C code is "too dumb to break invariants."

- **A2ML for attestation:** Rather than a proprietary binary format,
  Ochrance produces human-readable, machine-parseable attestation documents
  in A2ML format, enabling independent verification.

### 2.2 The ECHIDNA Platform

ECHIDNA (Extensible Calculus for Heuristic Investigation and Deductive
Navigational Analysis) is a neurosymbolic proof platform that combines
traditional proof search with neural guidance. Its architecture consists of:

- **Proof kernel:** A small, trusted core that verifies proofs. Currently
  supports Lean 4 and Coq; this work adds Idris2.

- **Tactic engine:** A search engine that explores the proof space using
  a combination of symbolic tactics (rewrite, induction, case split) and
  neural heuristics (learned tactic selection, lemma suggestion).

- **Neural oracle:** A transformer-based model trained on verified proof
  corpora. Given a proof goal, it suggests likely next steps, dramatically
  pruning the search space.

- **VeriSimDB:** A database of verified proofs indexed by structural
  similarity. When ECHIDNA encounters a new goal, it first searches
  VeriSimDB for similar proofs that can be adapted.

### 2.3 Idris2

Idris2 is a dependently typed programming language with first-class support
for linear types (Quantitative Type Theory). Key features relevant to this
work:

- **Dependent types:** Types can depend on values. `Vect n a` is a vector
  of exactly `n` elements of type `a`. `Fin n` is a natural number strictly
  less than `n`. These types enable compile-time enforcement of bounds
  checking, resource accounting, and protocol correctness.

- **Linear types:** A value with multiplicity `1` must be used exactly once.
  This is the foundation of Ephapax tokens: a repair token that is consumed
  exactly once, preventing both double-repair and missed-repair bugs.

- **Elaboration reflection:** Idris2's metaprogramming system allows
  tactics to be written in Idris2 itself, enabling custom proof automation.

- **FFI:** The `%foreign` directive calls C functions. This is how Idris2
  invokes the L1 C shims.

- **Erasure:** Proof terms are erased at compile time. A `VerifiedState`
  carrying a Merkle proof has zero runtime overhead for the proof component.

---

## 3. Architecture

### 3.1 Integration Overview

The integrated Ochrance-ECHIDNA system operates as follows:

```
  ┌───────────────────────────────────────────────────────────────┐
  │                     OCHRANCE FRAMEWORK                        │
  │                                                               │
  │  L0 Hardware ──> L1 Block Observer ──> L2 Merkle Root         │
  │                                         │                     │
  │                                         ▼                     │
  │                                    VerifiedState              │
  │                                         │                     │
  │                          ┌──────────────┼──────────────┐      │
  │                          ▼              ▼              ▼      │
  │                     L3 Repair     L4 Policy     L5 TUI       │
  │                     (Ephapax)     (Governor)    (q/p/z)      │
  └──────────────────────────┬────────────────────────────────────┘
                             │
                     Proof requests
                             │
                             ▼
  ┌───────────────────────────────────────────────────────────────┐
  │                     ECHIDNA PLATFORM                          │
  │                                                               │
  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
  │  │ Proof Kernel  │  │ Tactic Engine │  │ Neural Oracle     │   │
  │  │ (Idris2       │  │ (Symbolic +   │  │ (Transformer,     │   │
  │  │  backend)     │  │  Neural)      │  │  Flux.jl)         │   │
  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────────┘   │
  │         │                 │                  │               │
  │         └────────┬────────┘──────────────────┘               │
  │                  ▼                                            │
  │           ┌──────────────┐                                   │
  │           │  VeriSimDB    │                                   │
  │           │  (proof cache) │                                   │
  │           └──────────────┘                                   │
  └───────────────────────────────────────────────────────────────┘
```

**Workflow:**

1. Ochrance L1 reads raw blocks from the NVMe device.
2. Ochrance L2 constructs a Merkle tree and produces a `VerifiedState`.
3. For complex properties, L2 requests a proof from ECHIDNA.
4. ECHIDNA's tactic engine searches for a proof, guided by the neural oracle.
5. If found, the proof is verified by ECHIDNA's Idris2 backend.
6. The verified proof witness is serialised and embedded in an A2ML document.
7. L4 evaluates policies; L5 displays results; L3 repairs if needed.

### 3.2 Idris2 Prover Backend

The ECHIDNA Idris2 backend is a new component that enables ECHIDNA to
generate, compile, and verify Idris2 proof terms. It consists of:

#### 3.2.1 AST Representation

An in-memory representation of Idris2 terms, implemented in Rust:

```rust
/// Idris2 term representation for code generation.
/// This is a subset of Idris2's core language sufficient
/// for filesystem verification proofs.
pub enum IdrisTerm {
    /// Variable reference
    Var(String),
    /// Lambda abstraction (potentially linear)
    Lam {
        name: String,
        multiplicity: Multiplicity,
        ty: Box<IdrisTerm>,
        body: Box<IdrisTerm>,
    },
    /// Application
    App(Box<IdrisTerm>, Box<IdrisTerm>),
    /// Dependent function type (Pi type)
    Pi {
        name: String,
        multiplicity: Multiplicity,
        domain: Box<IdrisTerm>,
        codomain: Box<IdrisTerm>,
    },
    /// Data constructor
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
    /// Rewrite using an equality proof
    Rewrite {
        rule: Box<IdrisTerm>,
        body: Box<IdrisTerm>,
    },
}

pub enum Multiplicity {
    Zero,     // erased (compile-time only)
    One,      // linear (used exactly once)
    Omega,    // unrestricted
}
```

#### 3.2.2 Code Generator

The code generator transforms `IdrisTerm` AST nodes into syntactically
valid Idris2 source code:

```rust
impl IdrisTerm {
    /// Generate Idris2 source code from the AST.
    pub fn to_idris2(&self) -> String {
        match self {
            IdrisTerm::Var(name) => name.clone(),
            IdrisTerm::Lam { name, multiplicity, ty, body } => {
                let mult = match multiplicity {
                    Multiplicity::Zero => "0 ",
                    Multiplicity::One => "1 ",
                    Multiplicity::Omega => "",
                };
                format!("\\{}{} : {} => {}",
                    mult, name, ty.to_idris2(), body.to_idris2())
            }
            IdrisTerm::App(f, arg) => {
                format!("({} {})", f.to_idris2(), arg.to_idris2())
            }
            // ... remaining cases
            _ => todo!("Code generation for remaining term forms")
        }
    }
}
```

#### 3.2.3 Proof Template Library

Common proof patterns for filesystem properties are captured as templates:

```idris
-- Template: Merkle tree completeness proof
-- Given: a list of blocks and a Merkle tree
-- Prove: every block has a corresponding leaf in the tree
merkleCompletenessTemplate : (blocks : List Block)
                          -> (tree : MerkleTree)
                          -> {auto prf : AllInTree blocks tree}
                          -> Complete tree blocks
merkleCompletenessTemplate [] tree = EmptyComplete
merkleCompletenessTemplate (b :: bs) tree =
  let leafPrf = inTreeLookup b tree    -- from auto-search
      restPrf = merkleCompletenessTemplate bs tree
  in ConsComplete leafPrf restPrf
```

### 3.3 Neural Synthesis Pipeline

The neural proof synthesis pipeline operates in three stages:

#### 3.3.1 Proof Corpus and Training

Training data is extracted from:

- The Idris2 standard library (base, contrib, network packages).
- Verified properties from the Ochrance filesystem module.
- Synthetic proofs generated by symbolic search and simplified.

The training pipeline, implemented in Julia with Flux.jl:

```julia
# Training pipeline for neural proof synthesis
# Language: Julia (per RSR language policy)

using Flux
using Transformers

struct ProofSample
    goal::String           # Type to prove (the "question")
    context::Vector{String} # Available hypotheses
    proof::String          # Proof term (the "answer")
    tactics::Vector{String} # Tactic sequence that produced the proof
end

function train_proof_model(corpus::Vector{ProofSample};
                           epochs=100, batch_size=64)
    # Tokenise proof terms
    vocab = build_vocabulary(corpus)
    encoder = TransformerEncoder(
        d_model=512, nhead=8, num_layers=6,
        dim_feedforward=2048, dropout=0.1
    )
    decoder = TransformerDecoder(
        d_model=512, nhead=8, num_layers=6,
        dim_feedforward=2048, dropout=0.1
    )
    model = Seq2SeqModel(encoder, decoder, vocab)

    # Training loop
    opt = Adam(1e-4)
    for epoch in 1:epochs
        for batch in DataLoader(corpus, batch_size)
            goals = tokenise.(batch.goal, Ref(vocab))
            proofs = tokenise.(batch.proof, Ref(vocab))
            loss = seq2seq_loss(model, goals, proofs)
            Flux.train!(loss, Flux.params(model), opt)
        end
    end
    return model
end
```

#### 3.3.2 Beam Search Decoding

Given a proof goal, the neural model generates candidate proof terms
using beam search:

```julia
function synthesise_proof(model, goal::String;
                          beam_width=16, max_depth=100)
    # Tokenise the goal
    goal_tokens = tokenise(goal, model.vocab)

    # Beam search over proof terms
    beams = [(tokens=Int[], score=0.0)]
    for step in 1:max_depth
        candidates = []
        for beam in beams
            next_probs = model(goal_tokens, beam.tokens)
            top_k = partialsortperm(next_probs, 1:beam_width, rev=true)
            for k in top_k
                push!(candidates, (
                    tokens = [beam.tokens; k],
                    score = beam.score + log(next_probs[k])
                ))
            end
        end
        beams = sort(candidates, by=c -> c.score, rev=true)[1:beam_width]

        # Check if any beam produced a complete proof
        for beam in beams
            proof_text = detokenise(beam.tokens, model.vocab)
            if is_complete_proof(proof_text)
                return proof_text
            end
        end
    end
    return nothing  # synthesis failed
end
```

#### 3.3.3 Verification Loop

Every neural candidate is verified by the Idris2 type checker:

```julia
function verified_synthesis(model, goal::String;
                            max_attempts=16)
    candidates = synthesise_proof_candidates(model, goal, n=max_attempts)

    for (i, candidate) in enumerate(candidates)
        # Write candidate to a temporary Idris2 file
        proof_file = write_idris2_proof(goal, candidate)

        # Compile with Idris2 -- type checking IS verification
        result = run(`idris2 --check $(proof_file)`)

        if result.exitcode == 0
            @info "Proof verified on attempt $i/$max_attempts"
            return candidate
        else
            @debug "Candidate $i failed type checking" errors=result.stderr
        end
    end

    @warn "Neural synthesis failed for goal" goal
    return nothing
end
```

### 3.4 A2ML Integration

The A2ML (Attestation and Audit Markup Language) format is the serialisation
layer for all verification artefacts. Key features:

- **Hash algorithm agility:** SHA-256, SHA3-256, and BLAKE3 supported via
  a uniform `algorithm:hexdigest` notation.
- **Opaque proof witnesses:** Idris2 proof terms are base64-encoded and
  embedded in A2ML documents. They are opaque to the document format but
  meaningful to the Idris2 verifier.
- **Policy evaluation records:** L4 policy results are recorded in the
  `@policy` section, providing an audit trail of all integrity checks.
- **Chaining:** Each A2ML document references its predecessor via
  `previous_root`, forming a hash chain of attestations.

See `docs/A2ML-SPEC.md` for the complete EBNF grammar and section
specifications.

---

## 4. Implementation Strategy

### 4.1 Phase 1: Ochrance Core (Q1 2026, 12 weeks)

**Goal:** Build the foundational framework.

**Deliverables:**

1. **A2ML parser and serialiser** (Idris2): Recursive descent parser with
   error recovery, pretty-printer, round-trip property tests.

2. **VerifiedSubsystem interface** (Idris2): The core interface that all
   modules implement. Includes `VerifiedState`, `Ephapax` tokens, `HashAlgo`
   type family, and `Policy` composition.

3. **Filesystem module** (Idris2 + C): The reference implementation.
   C shims for NVMe I/O (~200 lines), Merkle tree construction, inclusion
   proof generation, corruption detection, CoW snapshot repair.

4. **TUI and telemetry** (Idris2): Terminal interface with q/p/z diagnostics,
   JSON-lines logging, OpenTelemetry integration.

### 4.2 Phase 2: ECHIDNA + Idris2 Backend (Q2 2026, 6 weeks)

**Goal:** Create the Idris2 prover backend for ECHIDNA.

**Deliverables:**

1. **Idris2 AST and code generator** (Rust): In-memory representation of
   Idris2 terms, source code generation, compilation.

2. **Proof search integration** (Rust): ECHIDNA tactic engine extended with
   Idris2-specific tactics, VeriSimDB integration.

3. **Ochrance-ECHIDNA bridge** (Idris2 + Rust): API for Ochrance to
   request proofs and embed witnesses in A2ML.

### 4.3 Phase 3: Neural Synthesis (Q3 2026, 8 weeks)

**Goal:** Add neural proof synthesis.

**Deliverables:**

1. **Training data pipeline** (Julia): Proof corpus extraction, feature
   engineering, data augmentation.

2. **Neural proof model** (Julia/Flux.jl): Transformer architecture,
   beam search decoding, confidence scoring.

3. **Verification loop** (Julia + Idris2): Neural candidate generation,
   Idris2 type-checker verification, feedback loop.

### 4.4 Phase 4: Production and Thesis (Q4 2026, 12 weeks)

**Goal:** Harden, evaluate, write thesis.

**Deliverables:**

1. **Production hardening:** Security audit, fuzzing, performance optimisation,
   containerised deployment.

2. **Evaluation:** Correctness, performance, neural synthesis quality.

3. **Thesis and publication:** MSc thesis, conference paper submission.

---

## 5. Evaluation

### 5.1 Correctness Evaluation

**Methodology:** Inject known corruption into test filesystems and verify
that Ochrance detects it with 100% reliability.

**Test cases:**

| Corruption Type | Expected Detection | Method |
|----------------|-------------------|--------|
| Single bit flip in a data block | Yes | Merkle leaf hash mismatch |
| Modified metadata block | Yes | Merkle internal node mismatch |
| Inserted block (filesystem grown) | Yes | Tree structure change |
| Deleted block (filesystem shrunk) | Yes | Missing leaf in tree |
| Reordered blocks | Yes | Position-dependent hashing |
| Modified SMART data (firmware bug) | Yes | SMART health check at L1 |
| Tampered audit log entry | Yes | Append-only policy at L4 |
| Replaced signed binary | Yes | Signature verification policy at L4 |

**Metrics:**

- True positive rate (must be 100% -- any miss is a critical bug).
- False positive rate (target: < 0.01%).
- Detection latency (time from corruption to alert).

### 5.2 Performance Evaluation

**Methodology:** Measure verification time as a function of filesystem size.

**Benchmarks:**

| Filesystem Size | Expected Verification Time | Merkle Tree Depth |
|-----------------|---------------------------|-------------------|
| 1 GB | < 2 seconds | 18 |
| 10 GB | < 10 seconds | 21 |
| 100 GB | < 60 seconds | 25 |
| 1 TB | < 5 minutes | 28 |

**Factors measured:**

- Merkle tree construction time (sequential vs. parallel).
- Proof generation time (symbolic vs. neural-assisted).
- A2ML serialisation overhead.
- TUI rendering impact (must be negligible).
- Memory usage (must fit in 256 MB for the verifier process).

### 5.3 Neural Synthesis Quality

**Methodology:** Evaluate the neural proof model on held-out verification
properties.

**Metrics:**

| Metric | Target |
|--------|--------|
| Synthesis success rate (valid proof generated) | >= 70% |
| Average synthesis time | < 5 seconds |
| Type-check rate of top-1 candidate | >= 40% |
| Type-check rate of top-16 candidates | >= 70% |
| Proof size vs. hand-written (lines of code) | Within 2x |

### 5.4 Case Studies

#### Case Study 1: NVMe Wear-Out Prediction

Using NVMe SMART data (available spare, media errors, data units written),
Ochrance predicts device wear-out and recommends proactive migration.

**Evaluation:** Compare Ochrance predictions against actual device failure
data from published studies (e.g., Google's fleet data, Backblaze drive
statistics).

#### Case Study 2: Boot Chain Verification

Using TPM PCR values and the Ochrance L0-L2 stack, verify that the boot
chain (UEFI firmware, bootloader, kernel, initramfs) has not been modified.

**Evaluation:** Simulate Evil Maid attacks (modified GRUB config, replaced
kernel image) and verify detection.

#### Case Study 3: Audit Log Integrity

Using the L4 append-only policy, verify that audit logs have not been
tampered with by an attacker who has gained root access.

**Evaluation:** Simulate post-compromise log tampering and verify detection
and alerting.

---

## 6. Related Work

### 6.1 Filesystem Integrity Tools

| Tool | Approach | Formal Proofs | Real-time | Repair |
|------|----------|---------------|-----------|--------|
| AIDE | File hash database | No | No | No |
| OSSEC | File hash + HIDS | No | Near-real-time | No |
| dm-verity | Block Merkle tree | No | Yes (read-time) | No (read-only) |
| fs-verity | File-level Merkle tree | No | Yes (read-time) | No (read-only) |
| IMA/EVM | Kernel integrity measurement | No | Yes | No |
| Ochrance | Block Merkle tree + Idris2 | **Yes** | **Yes** | **Yes** |

### 6.2 Verified Systems

- **seL4:** Formally verified microkernel (Isabelle/HOL proofs). Ochrance
  differs in scope: seL4 verifies the kernel; Ochrance verifies the
  filesystem state. They are complementary.

- **CertiKOS:** Verified concurrent OS kernel (Coq proofs). Again,
  complementary: CertiKOS verifies the kernel; Ochrance verifies data
  integrity at the filesystem level.

- **FSCQ/DFSCQ:** Verified file systems (Coq proofs by MIT PDOS).
  Closest to our work. Difference: FSCQ verifies the filesystem
  implementation; Ochrance verifies the filesystem *state* at runtime,
  regardless of the filesystem implementation.

### 6.3 Neural Proof Synthesis

- **AlphaProof (DeepMind):** Neural proof synthesis for mathematical
  competition problems. Uses Lean 4 as the verification backend. Our work
  differs in targeting systems verification (filesystem properties) rather
  than mathematics, and using Idris2 rather than Lean 4.

- **LeanDojo:** Tool for training machine learning models to prove
  Lean 4 theorems. Our Julia/Flux.jl pipeline serves a similar role for
  Idris2, but focuses on a narrower domain (filesystem properties) for
  higher synthesis rates.

- **Tactician (Coq):** Neural tactic prediction for Coq. Our ECHIDNA
  tactic engine draws inspiration from Tactician but extends it with
  VeriSimDB similarity search and linear-type-aware tactic selection.

---

## 7. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Idris2 compiler bugs affecting proof soundness | Critical | Low | Pin compiler version; upstream bug reports; fallback to manual proofs |
| Neural model generating plausible but incorrect proofs | Critical | None | All proofs verified by Idris2 type checker; neural is *suggestive*, not *authoritative* |
| NVMe hardware access requiring root privileges | Medium | High | `nvmet` loopback for testing; Linux capabilities (`CAP_SYS_RAWIO`) for production |
| Performance regression on large filesystems | Medium | Medium | Parallel Merkle tree construction; incremental verification; profiling |
| Thesis timeline overrun | High | Medium | Filesystem module alone is thesis-sufficient; ECHIDNA integration is bonus |
| C shim security vulnerability | High | Low | Minimal codebase (~200 lines); extensive fuzzing; optional Frama-C verification |

**Critical mitigation principle:** The neural oracle never bypasses the
Idris2 type checker. Even if the neural model is completely wrong, the
system remains sound because all proofs are verified. The neural component
affects *efficiency* (how quickly proofs are found), not *correctness*
(whether proofs are valid).

---

## 8. Future Work

### 8.1 Additional Modules

The `VerifiedSubsystem` interface is designed for extensibility:

- **Memory module:** Verified memory page integrity, stack canary
  verification, heap metadata consistency. Implementation: Idris2 + Rust
  (for `/proc/self/maps` introspection).

- **Network module:** Network flow verification, TLS certificate chain
  validation, DNS response integrity. Implementation: Idris2 + eBPF
  (for packet-level observation).

- **Crypto module:** Verified cryptographic operations with linkage to
  HACL* (formally verified crypto library). Ensures that crypto operations
  are not just *used* but *proven correct*.

### 8.2 Cross-Platform Support

The current implementation targets Linux with NVMe storage. Future work
includes:

- **FreeBSD:** ZFS integration (leveraging ZFS's built-in checksumming
  alongside Ochrance's formal proofs).
- **RISC-V:** PMP (Physical Memory Protection) integration for hardware-
  enforced isolation.
- **ARM TrustZone:** Secure world execution for the L0/L1 layers.

### 8.3 Distributed Verification

Extending Ochrance to verify distributed filesystem state (e.g., Ceph,
GlusterFS) by constructing Merkle trees across multiple nodes with
consensus-based root agreement.

### 8.4 Industry Partnerships

Potential collaboration opportunities:

- **NVMe consortium:** Standardised SMART field interpretation.
- **RISC-V foundation:** PMP integration for hardware root of trust.
- **Chainguard:** Supply chain security for containerised Ochrance
  deployments.
- **The Open University:** Academic publication and thesis supervision.

---

## 9. Conclusion

We have presented Ochrance, a neurosymbolic filesystem verification
framework that provides machine-checkable proofs of filesystem integrity.
By combining Idris2 dependent types, Merkle tree cryptography, and
ECHIDNA's neural proof synthesis, Ochrance addresses a gap in the existing
filesystem verification landscape: the absence of formal, independently
verifiable correctness certificates.

The key insight is that filesystem integrity is not merely a runtime
checking problem -- it is a *proof* problem. Every verified state should
carry a certificate that any independent verifier can check without
trusting the verification tool itself. Idris2's dependent types make this
possible; ECHIDNA's neural synthesis makes it practical.

The layered architecture (L0-L5) separates concerns cleanly: hardware
roots of trust (L0), minimal I/O (L1), formal proofs (L2), atomic repair
(L3), system integrity policies (L4), and human-facing diagnostics (L5).
The `VerifiedSubsystem` interface enables future extension beyond
filesystems to memory, network, and cryptographic verification.

We plan to evaluate Ochrance on real NVMe hardware, measuring correctness
(100% corruption detection), performance (verification time vs. filesystem
size), and neural synthesis quality (70%+ success rate). The filesystem
module serves as the reference implementation and thesis scope; the
integrated ECHIDNA backend and neural synthesis pipeline demonstrate the
neurosymbolic approach's potential.

---

## References

1. Brady, E. (2021). *Idris 2: Quantitative Type Theory in Practice*.
   ECOOP 2021.

2. Atkey, R. (2018). *Syntax and Semantics of Quantitative Type Theory*.
   LICS 2018.

3. Chen, H., et al. (2016). *Using Crash Hoare Logic for Certifying the
   FSCQ File System*. SOSP 2015.

4. Klein, G., et al. (2009). *seL4: Formal Verification of an OS Kernel*.
   SOSP 2009.

5. Merkle, R. (1988). *A Digital Signature Based on a Conventional
   Encryption Function*. CRYPTO 1987.

6. NVM Express (2024). *NVM Express Base Specification, Revision 2.1*.

7. Trusted Computing Group (2019). *TPM 2.0 Library Specification*.

8. AlphaProof Team, DeepMind (2024). *AI Achieves Silver-Medal Standard
   Solving International Mathematical Olympiad Problems*.

9. Yang, K., et al. (2023). *LeanDojo: Theorem Proving with Retrieval-
   Augmented Language Models*. NeurIPS 2023.

10. Blaauwbroek, L., et al. (2020). *Tactician: A Semantic Reasoning
    Engine for Coq*. CICM 2020.

11. HACL* Team (2017). *HACL*: A Verified Modern Cryptographic Library*.
    CCS 2017.

12. Zinzindohoue, J.K., et al. (2017). *A Verified Extensible Library of
    Elliptic Curves*. IEEE CSF 2017.

13. Gu, R., et al. (2016). *CertiKOS: An Extensible Architecture for
    Building Certified Concurrent OS Kernels*. OSDI 2016.

14. Innes, M. (2018). *Flux: Elegant Machine Learning with Julia*.
    JOSS 2018.

15. Linux Kernel Documentation (2024). *dm-verity: Device-Mapper's
    Verification Target*.

16. Linux Kernel Documentation (2024). *fs-verity: Read-Only File-Based
    Authenticity Protection*.

---

## Appendix A: Idris2 Type Signatures

```idris
-- Core types from the Ochrance framework

-- Hash algorithm type family
data HashAlgo = SHA256 | SHA3_256 | BLAKE3

-- Hash output indexed by algorithm
data Hash : HashAlgo -> Type where
  MkHash : Vect (hashLen algo) Bits8 -> Hash algo

-- Merkle tree indexed by depth and hash algorithm
data MerkleTree : (depth : Nat) -> (algo : HashAlgo) -> Type where
  Leaf : (hash : Hash algo) -> MerkleTree 0 algo
  Node : (hash : Hash algo)
      -> (left : MerkleTree d algo)
      -> (right : MerkleTree d algo)
      -> MerkleTree (S d) algo

-- Verified state: a Merkle root with a completeness proof
data VerifiedState : Type where
  MkVerified : (root : Hash algo)
            -> (depth : Nat)
            -> (blockCount : Nat)
            -> (proof : MerkleProof algo depth blockCount)
            -> (timestamp : Posix)
            -> VerifiedState

-- Ephapax: linear-type repair token
data Ephapax : RepairAction -> Type where
  MkEphapax : (1 _ : RepairAction) -> Ephapax action

-- Policy: decidable predicate over verified state
Policy : Type
Policy = (s : VerifiedState) -> Dec (Satisfies s)

-- VerifiedSubsystem interface
interface VerifiedSubsystem (m : Type -> Type) where
  enumerateUnits : m (List UnitId)
  readUnit       : UnitId -> m (Either ReadError RawBytes)
  writeUnit      : UnitId -> RawBytes -> m (Either WriteError ())
  hashUnit       : RawBytes -> Hash algo
  healthCheck    : m HealthStatus
```

## Appendix B: A2ML Grammar Summary

See `docs/A2ML-SPEC.md` for the complete EBNF grammar. Summary:

- Header: `a2ml/1.0`
- Required sections: `@manifest`, `@refs`
- Optional sections: `@attestation`, `@policy`, `@audit`
- Hash format: `algorithm:hexdigest`
- Blob format: `base64(...)`
- Timestamps: ISO 8601 with mandatory `Z` suffix
- Comments: `-- ...` (line comment)
