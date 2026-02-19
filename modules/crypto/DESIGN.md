# Crypto Module — Design Document

**Status**: Future work (not yet implemented)

## Overview

The crypto verification subsystem will provide verified cryptographic
primitive usage. This is not a crypto library — it verifies that existing
crypto operations are being used correctly:

- Hash algorithm selection validation (no MD5/SHA-1 in production)
- Key length verification against policy minimums
- Signature verification chain integrity
- Entropy source quality attestation

## Planned Modules

| Module                          | Purpose                                |
|---------------------------------|----------------------------------------|
| `Ochrance.Crypto.Types`         | Core types (algorithms, keys, sigs)    |
| `Ochrance.Crypto.Policy`        | Algorithm policy enforcement           |
| `Ochrance.Crypto.KeyVerify`     | Key length and format verification     |
| `Ochrance.Crypto.SigChain`      | Signature chain integrity              |
| `Ochrance.Crypto.Entropy`       | Entropy source quality attestation     |

## Verification Modes

- **Lax**: Check that no banned algorithms are in use
- **Checked**: Verify key lengths and hash outputs against policy
- **Attested**: Full signature chain verification with provenance proofs

## Dependencies

- Requires `Ochrance.Framework.*` (core interface and proof types)
- FFI to C or Zig for actual hash computation (BLAKE3, SHA-256)
- May integrate with the Ochrance ABI layer for cross-platform hash FFI

## Design Principles

- This module does NOT implement crypto — it verifies crypto usage
- All actual hash computation is delegated to proven implementations via FFI
- Policy is declarative (A2ML manifests), not hardcoded
- Quantum-safe algorithm support planned (see EXHIBIT-B-QUANTUM-SAFE.txt)

## Open Questions

- Should we verify OpenSSL/BoringSSL configuration, or abstract over backends?
- How to handle algorithm deprecation gracefully (transition periods)?
- Integration with certificate transparency logs?
