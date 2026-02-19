<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# A2ML Specification: Attestation and Audit Markup Language

> **Version:** 1.0.0-draft
> **Status:** Working Draft
> **Last updated:** 2026-02-19
> **Author:** Jonathan D.A. Jewell, The Open University

## 1. Introduction

A2ML (Attestation and Audit Markup Language) is a structured document format
for recording cryptographic attestation data, audit trails, and policy
evaluation results produced by the Ochrance framework.

A2ML is designed to be:

- **Machine-parseable:** Strict grammar with no ambiguity.
- **Hash-agile:** Supports multiple hash algorithms without format changes.
- **Proof-carrying:** Embeds opaque proof witnesses from Idris2.
- **Auditable:** Every A2ML document is self-describing and timestamped.
- **Compact:** Minimal overhead for high-frequency attestation cycles.

A2ML documents are produced at L2 (Merkle Root) of the Ochrance architecture
and consumed by L4 (Policy Governor), L5 (TUI/Telemetry), and external
verification systems.

---

## 2. Document Structure

An A2ML document consists of a header line followed by one or more sections.
Each section begins with a section tag (`@name`) and contains key-value
pairs and/or nested blocks.

### 2.1 High-Level Structure

```
a2ml/1.0
@manifest { ... }
@refs { ... }
@attestation { ... }   -- optional
@policy { ... }         -- optional
@audit { ... }          -- optional
```

### 2.2 Required Sections

Every valid A2ML document MUST contain `@manifest` and `@refs`.

### 2.3 Optional Sections

The `@attestation`, `@policy`, and `@audit` sections are optional. Parsers
MUST accept documents with or without them. Unknown sections MUST be
preserved but MAY be ignored by consumers.

---

## 3. EBNF Grammar

```ebnf
(* A2ML v1.0 EBNF Grammar *)

document        = header , section+ ;
header          = "a2ml/" , version , newline ;
version         = digit+ , "." , digit+ ;

section         = section_tag , "{" , newline , field* , "}" , newline ;
section_tag     = "@" , identifier ;

field           = key , ":" , value , newline
                | key , "{" , newline , field* , "}" , newline ;

key             = identifier ;
value           = string_value
                | hash_value
                | integer_value
                | timestamp_value
                | list_value
                | blob_value
                | boolean_value ;

string_value    = '"' , utf8_char* , '"' ;
hash_value      = hash_algo , ":" , hex_string ;
integer_value   = digit+ ;
timestamp_value = iso8601 ;
list_value      = "[" , value , ("," , value)* , "]" ;
blob_value      = "base64(" , base64_chars , ")" ;
boolean_value   = "true" | "false" ;

hash_algo       = "sha256" | "sha3-256" | "blake3" ;
hex_string      = hex_digit+ ;
base64_chars    = (letter | digit | "+" | "/" | "=")+ ;
iso8601         = digit{4} , "-" , digit{2} , "-" , digit{2} ,
                  "T" , digit{2} , ":" , digit{2} , ":" , digit{2} ,
                  ("." , digit+)? , "Z" ;

identifier      = (letter | "_") , (letter | digit | "_" | "-")* ;
newline         = "\n" ;
digit           = "0" | "1" | ... | "9" ;
hex_digit       = digit | "a" | "b" | "c" | "d" | "e" | "f" ;
letter          = "a" | ... | "z" | "A" | ... | "Z" ;
utf8_char       = ? any valid UTF-8 character except unescaped '"' ? ;

(* Comments *)
comment         = "--" , ? any character except newline ? , newline ;
```

---

## 4. Section Specifications

### 4.1 `@manifest` (Required)

The manifest section identifies the document and the system that produced it.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique document identifier (UUID v7 recommended) |
| `version` | string | Yes | A2ML specification version used |
| `producer` | string | Yes | Identifier of the producing system |
| `produced_at` | timestamp | Yes | When the document was created |
| `subsystem` | string | Yes | Which VerifiedSubsystem produced this (e.g., "filesystem") |
| `device` | string | No | Device identifier (e.g., NVMe namespace) |
| `hostname` | string | No | Hostname of the producing machine |

**Example:**

```
@manifest {
  id: "01956a3b-7c4d-7e8f-9a1b-2c3d4e5f6789"
  version: "1.0"
  producer: "ochrance-framework/0.1.0"
  produced_at: 2026-02-19T14:30:00.000Z
  subsystem: "filesystem"
  device: "/dev/nvme0n1"
  hostname: "thesis-workstation"
}
```

### 4.2 `@refs` (Required)

The refs section contains the cryptographic root(s) and block references
that anchor this attestation.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `merkle_root` | hash | Yes | The Merkle tree root hash |
| `algorithm` | string | Yes | Hash algorithm used throughout |
| `block_count` | integer | Yes | Number of blocks in the verified set |
| `tree_depth` | integer | Yes | Depth of the Merkle tree |
| `leaf_size` | integer | No | Block size in bytes (default: 4096) |
| `previous_root` | hash | No | Root hash of the previous attestation |
| `chain_length` | integer | No | Number of attestations in this chain |

**Example:**

```
@refs {
  merkle_root: sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
  algorithm: "sha256"
  block_count: 262144
  tree_depth: 18
  leaf_size: 4096
  previous_root: sha256:f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5
  chain_length: 42
}
```

### 4.3 `@attestation` (Optional)

The attestation section contains proof witnesses and hardware attestation
data. This is where Idris2-generated proofs are embedded as opaque blobs.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Attestation type: "software", "tpm", "hybrid" |
| `proof_witness` | blob | No | Base64-encoded Idris2 proof witness |
| `tpm_quote` | blob | No | Base64-encoded TPM quote |
| `pcr_values` | list | No | List of PCR index:hash pairs |
| `nonce` | hash | No | Anti-replay nonce used in TPM quote |
| `verified_at` | timestamp | Yes | When verification completed |
| `verification_duration_ms` | integer | No | How long verification took |

**Example:**

```
@attestation {
  type: "hybrid"
  proof_witness: base64(SGVsbG8gV29ybGQhIFRoaXMgaXMgYW4gSWRyaXMyIHByb29mIHdpdG5lc3Mu...)
  tpm_quote: base64(VFBNIHNpZ25lZCBxdW90ZSBkYXRhIGdvZXMgaGVyZS4uLg==)
  pcr_values: [
    sha256:0000000000000000000000000000000000000000000000000000000000000000,
    sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
  ]
  nonce: sha256:deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
  verified_at: 2026-02-19T14:30:01.234Z
  verification_duration_ms: 1234
}
```

### 4.4 `@policy` (Optional)

The policy section records the results of L4 policy evaluation against
the verified state.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `evaluated_at` | timestamp | Yes | When policy evaluation completed |
| `total_policies` | integer | Yes | Number of policies evaluated |
| `passed` | integer | Yes | Number of policies that passed |
| `failed` | integer | Yes | Number of policies that failed |
| `skipped` | integer | No | Number of policies skipped (not applicable) |
| `violations` | block | No | Details of each failing policy |

**Violation sub-block fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `policy_id` | string | Yes | Unique policy identifier |
| `severity` | string | Yes | "critical", "warning", "info" |
| `description` | string | Yes | Human-readable violation description |
| `evidence` | hash | No | Hash of the evidence data |
| `remediation` | string | No | Suggested remediation action |

**Example:**

```
@policy {
  evaluated_at: 2026-02-19T14:30:02.000Z
  total_policies: 10
  passed: 9
  failed: 1
  skipped: 0
  violations {
    violation {
      policy_id: "signed-binary-exec"
      severity: "critical"
      description: "Unsigned binary detected: /usr/local/bin/suspect"
      evidence: sha256:badc0ffee0ddf00dbadc0ffee0ddf00dbadc0ffee0ddf00dbadc0ffee0ddf00d
      remediation: "Remove or sign the binary with an approved key"
    }
  }
}
```

### 4.5 `@audit` (Optional)

The audit section records a chronological log of actions taken by the
framework, including repairs (L3) and state transitions.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `entries` | block | Yes | List of audit log entries |

**Entry sub-block fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestamp` | timestamp | Yes | When the action occurred |
| `action` | string | Yes | Action type (see enumeration below) |
| `target` | string | No | What was acted upon (block ID, file path) |
| `result` | string | Yes | "success", "failure", "rollback" |
| `snapshot_id` | string | No | CoW snapshot used for this action |
| `details` | string | No | Additional context |

**Action types:**

- `verify` -- Full or partial verification pass
- `repair_block` -- Block-level repair via Ephapax
- `repair_metadata` -- Metadata repair via Ephapax
- `quarantine` -- File quarantined due to corruption
- `rebuild_index` -- Index rebuilt from verified blocks
- `snapshot_create` -- CoW snapshot created
- `snapshot_rollback` -- Rolled back to a snapshot
- `policy_evaluate` -- Policy evaluation completed

---

## 5. Hash Algorithm Agility

A2ML supports multiple hash algorithms to accommodate evolving cryptographic
standards. The algorithm is declared once in `@refs.algorithm` and applies
to all hash values in the document unless overridden.

### 5.1 Supported Algorithms

| Identifier | Algorithm | Output Size | Status |
|------------|-----------|-------------|--------|
| `sha256` | SHA-256 (FIPS 180-4) | 256 bits | Default, mandatory to implement |
| `sha3-256` | SHA3-256 (FIPS 202) | 256 bits | Recommended for new deployments |
| `blake3` | BLAKE3 | 256 bits | Supported, excellent performance |

### 5.2 Hash Value Format

Hash values are always written as `algorithm:hexdigest`:

```
sha256:a1b2c3d4...
sha3-256:e5f6a7b8...
blake3:c9d0e1f2...
```

### 5.3 Algorithm Negotiation

When verifying an A2ML document produced by another system, the verifier
MUST support the algorithm declared in `@refs.algorithm`. If the algorithm
is not supported, verification MUST fail with error code `UNSUPPORTED_ALGO`.

### 5.4 Future Algorithms

New algorithms can be added by:

1. Adding a new constructor to the `HashAlgo` type in Idris2.
2. Implementing the hash function in the appropriate FFI layer.
3. Registering the algorithm identifier in this specification.
4. Post-quantum algorithms (e.g., SPHINCS+) are anticipated but not yet specified.

---

## 6. Opaque Payloads (Proof Witnesses)

### 6.1 Encoding

Proof witnesses generated by Idris2 are opaque byte sequences. They are
embedded in A2ML using base64 encoding:

```
proof_witness: base64(SGVsbG8gV29ybGQ=)
```

### 6.2 Semantics

- The content of a proof witness is meaningful only to the Idris2 verifier
  that generated it.
- A2ML parsers MUST preserve proof witnesses byte-for-byte but are NOT
  required to interpret them.
- Proof witnesses MUST NOT be modified, truncated, or re-encoded.

### 6.3 Size Constraints

- Individual proof witnesses: maximum 1 MiB (1,048,576 bytes before
  base64 encoding).
- Total A2ML document size: maximum 16 MiB.
- Implementations SHOULD reject documents exceeding these limits.

### 6.4 Witness Verification

To verify a proof witness:

1. Decode the base64 payload.
2. Pass the decoded bytes to the Idris2 `verifyWitness` function along
   with the `VerifiedState` from `@refs`.
3. The function returns `Yes prf` (valid) or `No contra` (invalid).

---

## 7. Security Considerations

### 7.1 Injection Attacks

- A2ML parsers MUST reject documents containing null bytes (`\0`) outside
  of base64-encoded blobs.
- String values MUST NOT contain unescaped control characters (U+0000
  through U+001F, except `\n` and `\t`).
- Section tags MUST match the regex `^@[a-z][a-z0-9_-]*$`.
- Key names MUST match the regex `^[a-z][a-z0-9_]*$`.

### 7.2 Denial of Service

- **Size limits:** Documents exceeding 16 MiB MUST be rejected before parsing.
- **Nesting depth:** Maximum nesting depth is 8 levels. Deeper nesting
  MUST be rejected.
- **Field count:** Maximum 1024 fields per section. Excess fields MUST
  be rejected.
- **List length:** Maximum 65536 elements per list value.

### 7.3 Hash Collision Resistance

- SHA-256 provides 128-bit collision resistance, which is sufficient for
  current threat models.
- For post-quantum resistance, SHA3-256 or BLAKE3 SHOULD be used.
- A2ML does NOT specify hash truncation; full-length digests are always used.

### 7.4 Replay Protection

- Each A2ML document contains a `produced_at` timestamp and a unique `id`.
- When used with TPM attestation, the `nonce` field provides anti-replay
  guarantees.
- Consumers SHOULD maintain a sliding window of recently seen document IDs
  to detect replays.

### 7.5 Transport Security

- A2ML documents do not provide confidentiality. They are integrity artifacts.
- If confidentiality is required, the transport layer (TLS, SSH, etc.)
  MUST provide it.
- A2ML documents SHOULD be signed using the framework's signing key before
  transmission to untrusted parties.

### 7.6 Canonicalisation

- For signature verification, A2ML documents MUST be canonicalised:
  - UTF-8 encoding, NFC normalisation.
  - Unix line endings (`\n`, not `\r\n`).
  - No trailing whitespace on any line.
  - No trailing newline after the final `}`.
  - Fields within a section sorted lexicographically by key name.

---

## 8. MIME Type

The recommended MIME type for A2ML documents is:

```
application/vnd.ochrance.a2ml+text
```

File extension: `.a2ml`

---

## 9. Example: Complete A2ML Document

```
a2ml/1.0
-- Ochrance filesystem attestation
-- Produced by ochrance-framework v0.1.0

@manifest {
  id: "01956a3b-7c4d-7e8f-9a1b-2c3d4e5f6789"
  version: "1.0"
  producer: "ochrance-framework/0.1.0"
  produced_at: 2026-02-19T14:30:00.000Z
  subsystem: "filesystem"
  device: "/dev/nvme0n1"
  hostname: "thesis-workstation"
}

@refs {
  merkle_root: sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
  algorithm: "sha256"
  block_count: 262144
  tree_depth: 18
  leaf_size: 4096
  previous_root: sha256:f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5
  chain_length: 42
}

@attestation {
  type: "software"
  proof_witness: base64(UHJvb2Ygd2l0bmVzcyBmb3IgTWVya2xlIHRyZWUgY29tcGxldGVuZXNzIGFuZCBjb25zaXN0ZW5jeQ==)
  verified_at: 2026-02-19T14:30:01.234Z
  verification_duration_ms: 1234
}

@policy {
  evaluated_at: 2026-02-19T14:30:02.000Z
  total_policies: 10
  passed: 10
  failed: 0
}

@audit {
  entries {
    entry {
      timestamp: 2026-02-19T14:30:00.000Z
      action: "verify"
      result: "success"
      details: "Full filesystem verification completed"
    }
    entry {
      timestamp: 2026-02-19T14:30:02.000Z
      action: "policy_evaluate"
      result: "success"
      details: "All 10 policies passed"
    }
  }
}
```

---

## 10. References

- FIPS 180-4: Secure Hash Standard (SHA-256)
- FIPS 202: SHA-3 Standard
- BLAKE3 specification: <https://github.com/BLAKE3-team/BLAKE3-specs>
- RFC 4648: Base Encodings (base64)
- RFC 3339: Date and Time on the Internet (ISO 8601 profile)
- Ochrance Architecture: `docs/ARCHITECTURE.md`
