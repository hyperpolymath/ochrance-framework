# TEST-NEEDS.md — ochrance-framework

## CRG Grade: C — ACHIEVED 2026-04-04

> Generated 2026-03-29 by punishing audit.

## Current State

| Category     | Count | Notes |
|-------------|-------|-------|
| Unit tests   | 0     | None |
| Integration  | 0     | None |
| E2E          | 0     | None |
| Benchmarks   | 0     | None |

**Source modules:** 13 Idris2 files in ochrance-core/ covering: Framework (Interface, Proof, Error, Progressive), A2ML (Types, Lexer, Parser, Validator, Serializer), Filesystem (Types, Merkle, Verify, Repair). No FFI layer yet.

## What's Missing

### P2P (Property-Based) Tests
- [ ] A2ML parser: arbitrary A2ML input fuzzing
- [ ] A2ML serializer: roundtrip property tests (parse -> serialize -> parse = identity)
- [ ] Filesystem Merkle: tree construction invariant tests
- [ ] Validator: arbitrary schema + data property tests

### E2E Tests
- [ ] A2ML pipeline: parse -> validate -> serialize -> deserialize
- [ ] Filesystem: build Merkle tree -> verify -> introduce corruption -> detect -> repair
- [ ] Progressive: full progressive enhancement lifecycle
- [ ] Framework interface: implementation compliance testing

### Aspect Tests
- **Security:** No tests for A2ML injection, Merkle tree forgery, filesystem repair authorization
- **Performance:** No parsing or verification benchmarks
- **Concurrency:** No tests for concurrent filesystem verification
- **Error handling:** No tests for malformed A2ML, corrupted Merkle nodes, repair failure scenarios

### Build & Execution
- [ ] Idris2 compilation of all 13 .idr files
- [ ] Type-checking as verification

### Benchmarks Needed
- [ ] A2ML parse time vs document size
- [ ] Merkle tree construction time vs file count
- [ ] Verification speed for filesystem integrity
- [ ] Repair operation throughput

### Self-Tests
- [ ] A2ML: parse the framework's own A2ML documents
- [ ] Merkle: verify the framework's own source tree
- [ ] All Idris2 proofs type-check

## Priority

**CRITICAL.** 13 Idris2 modules with ZERO tests of any kind. A filesystem integrity framework (Merkle, Verify, Repair) with no tests is dangerous. The A2ML parser/serializer/validator trio needs comprehensive testing — these are parsing-heavy modules where edge cases are the norm.

## FAKE-FUZZ ALERT

- `tests/fuzz/placeholder.txt` is a scorecard placeholder inherited from rsr-template-repo — it does NOT provide real fuzz testing
- Replace with an actual fuzz harness (see rsr-template-repo/tests/fuzz/README.adoc) or remove the file
- Priority: P2 — creates false impression of fuzz coverage
