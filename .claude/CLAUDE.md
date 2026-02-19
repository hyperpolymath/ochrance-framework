# Ochránce Framework — Claude Instructions

## Project Identity

**Name**: Ochránce (Czech: protector, defender, guardian)
**Pronunciation**: /ˈoxraːnt͡sɛ/ (OH-khran-tseh)
**Repository**: ochrance-framework
**Author**: Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>
**License**: PMPL-1.0-or-later

## Naming Convention (CRITICAL)

- **In prose/docs/comments**: Always "Ochránce" (with háček on á)
- **In code/paths/URLs**: Always "ochrance" (ASCII-safe, no diacritics)
- **Module prefix**: `Ochrance.` (e.g., `Ochrance.A2ML.Parser`)
- **Binary names**: `ochrance`, `ochrance-verify`, `ochrance-daemon`
- **NEVER**: "Sentinel" (old name, fully rebranded)

## Architecture

6-layer trust pyramid (L0-L5):
- L0: Hardware Root (TPM, Secure Boot, RISC-V PMP) — no code
- L1: Block Observer (thin C shims, ~200 lines, NVMe via libnvme)
- L2: Merkle Root + A2ML (Idris2 proofs, VerifiedState witness)
- L3: Atomic State / Ephapax (linear type repair, CoW snapshots)
- L4: Policy Governor (system integrity ONLY — never spelling/style/content)
- L5: TUI / Telemetry (q/p/z semantic diagnostics)

Framework-first: `VerifiedSubsystem` interface with pluggable modules.

## Languages

| Language | Purpose | Location |
|----------|---------|----------|
| Idris2 | Core framework, proofs, parser, verification | `ochrance-core/` |
| C | Thin NVMe syscall wrappers (<300 lines) | `ffi/c/` |
| Rust | ECHIDNA Idris2 backend (future) | `integrations/echidna/` |
| Julia | Neural proof synthesis (future) | `training/` |

## Critical Invariants

1. **Totality**: All parser and verification functions MUST have `total` annotation
2. **Thin C FFI**: C shims are syscall wrappers ONLY — no business logic, no state
3. **Progressive strictness**: All verification supports Lax/Checked/Attested modes
4. **L4 boundary**: Policy Governor enforces system integrity (signed binaries, auth, access control) — NEVER content validation (spelling, formatting, style)
5. **SCM files**: ONLY in `.machine_readable/`, NEVER in root
6. **No unsafe patterns**: No `believe_me`, `assert_total`, `unsafePerformIO` in Idris2

## Build Commands

```bash
just build          # Build Idris2 + C shims
just check          # Type-check all modules
just check-totality # Verify total annotations
just test           # Run test suite
just bench          # Run benchmarks
just rsr-check      # Check RSR compliance
just spdx-check     # Verify SPDX headers
```

## File Organization

- Source: `ochrance-core/` (Idris2, matches module hierarchy)
- FFI: `ffi/c/` (thin C shims)
- Docs: `docs/` (architecture, spec, white paper, guide)
- Tests: `tests/`
- Module docs: `modules/{filesystem,memory,network,crypto}/`
- Integrations: `integrations/{echidna,ostree}/`

## ECHIDNA Integration

ECHIDNA is our neurosymbolic theorem proving platform.
- Adding Idris2 as 13th prover backend
- Neural proof synthesis for Ochránce theorems
- Repo: https://github.com/hyperpolymath/echidna

## Key Types

```idris
-- Core interface
interface VerifiedSubsystem (sub : Type) where
  State : Type
  Manifest : Type
  verify : State -> Manifest -> Either Error (Proof State Manifest)

-- Proof witnesses
data Proof : (state : Type) -> (manifest : Type) -> Type where
  StructureValid : ...  -- Lax mode
  HashesMatch : ...     -- Checked mode
  FullyAttested : ...   -- Attested mode

-- Error diagnostics
record Diagnostic where
  q : String  -- What happened
  p : String  -- Why it matters
  z : String  -- Impact zone
```

## Research Context

Thesis: "Dependent Types for Verified Systems: A Framework for Subsystem Integrity"
Institution: The Open University
Timeline: 12 months (Q1-Q4 2026)
Target venues: ICFP, PLDI, SOSP
