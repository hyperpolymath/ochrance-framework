<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# L4 Policy Governor: Valid Policies and Anti-Patterns

> **Version:** 1.0.0-draft
> **Last updated:** 2026-02-19

## 1. What L4 Is (and Is Not)

The L4 Policy Governor enforces **system integrity constraints** over
cryptographically verified filesystem state. It answers questions of the form:

> "Given this verified state, does the system satisfy this integrity property?"

L4 is **NOT** a general-purpose rule engine. It does not govern content
quality, code style, natural language, or business logic. Those concerns
belong to other tools (linters, CI/CD pipelines, application code).

**The litmus test:** If a policy violation could lead to a security breach,
privilege escalation, data corruption, or loss of system integrity, it
belongs in L4. If a policy violation is merely aesthetically displeasing
or violates a coding convention, it does NOT belong in L4.

---

## 2. Policy Specification in Idris2

Every L4 policy is a decidable predicate over `VerifiedState`:

```idris
-- A Policy is a function that examines verified state and returns
-- either a proof that the state satisfies the policy, or a proof
-- that it does not (with a machine-checkable counter-example).
Policy : Type
Policy = (s : VerifiedState) -> Dec (Satisfies s)
```

Policies are:

- **Total:** They always terminate (no infinite loops).
- **Decidable:** They return `Yes prf` or `No contra`, never "maybe."
- **Pure:** They do not perform I/O or modify state.
- **Composable:** Policies can be combined with `AllOf`, `AnyOf`, `Not`.

---

## 3. Valid L4 Policy Examples

### Policy 1: Signed Binary Execution

**Description:** All executable files in `/usr/bin/`, `/usr/sbin/`, and
`/usr/local/bin/` must have a valid code signature.

**Rationale:** Prevents execution of tampered or injected binaries.

```idris
signedBinaryPolicy : Policy
signedBinaryPolicy state =
  let executables = filter isExecutable (allFiles state)
      unsigned = filter (not . hasValidSignature) executables
  in case unsigned of
       [] => Yes AllSigned
       (f :: fs) => No (UnsignedBinary f)
```

**Severity:** Critical

---

### Policy 2: Kernel Module Signing

**Description:** All loaded kernel modules must be signed with a key present
in the system keyring.

**Rationale:** Prevents loading of malicious kernel modules that could
compromise the entire system.

```idris
kernelModulePolicy : Policy
kernelModulePolicy state =
  let modules = kernelModules state
      unverified = filter (not . moduleSignatureValid) modules
  in case unverified of
       [] => Yes AllModulesSigned
       (m :: ms) => No (UnsignedModule m)
```

**Severity:** Critical

---

### Policy 3: Configuration File Immutability

**Description:** Critical configuration files (`/etc/fstab`, `/etc/shadow`,
`/etc/sudoers`, `/etc/ssh/sshd_config`) must not have changed since the
last verified snapshot.

**Rationale:** Detects unauthorised modifications to security-sensitive
configuration.

```idris
configImmutabilityPolicy : Policy
configImmutabilityPolicy state =
  let criticalConfigs = ["/etc/fstab", "/etc/shadow", "/etc/sudoers",
                         "/etc/ssh/sshd_config"]
      changed = filter (hasChangedSince (previousRoot state)) criticalConfigs
  in case changed of
       [] => Yes ConfigsUnchanged
       (c :: cs) => No (ConfigModified c)
```

**Severity:** Critical

---

### Policy 4: Permission Mask Constraints

**Description:** No file outside of `/tmp` and `/var/tmp` may be
world-writable (mode `o+w`).

**Rationale:** World-writable files outside temp directories are a common
vector for privilege escalation.

```idris
noWorldWritablePolicy : Policy
noWorldWritablePolicy state =
  let nonTemp = filter (not . isTempDir) (allFiles state)
      worldWritable = filter isWorldWritable nonTemp
  in case worldWritable of
       [] => Yes NoWorldWritable
       (f :: fs) => No (WorldWritableFile f)
```

**Severity:** Warning

---

### Policy 5: Boot Chain Integrity

**Description:** The boot chain (bootloader, kernel, initramfs) must match
the expected hashes recorded in the TPM PCR values.

**Rationale:** Detects boot-level tampering (Evil Maid attacks, rootkits).

```idris
bootChainPolicy : Policy
bootChainPolicy state =
  let expected = expectedPCRValues state
      actual = tpmPCRValues state
  in if expected == actual
     then Yes BootChainValid
     else No (PCRMismatch expected actual)
```

**Severity:** Critical

---

### Policy 6: Certificate Pinning

**Description:** TLS certificates for critical services (stored in
`/etc/ssl/certs/` and `/etc/pki/`) must match pinned fingerprints.

**Rationale:** Detects certificate substitution attacks (compromised CA,
MITM proxies).

```idris
certPinningPolicy : Policy
certPinningPolicy state =
  let pinnedCerts = certPins state
      currentCerts = installedCerts state
      mismatches = findMismatches pinnedCerts currentCerts
  in case mismatches of
       [] => Yes CertsPinned
       (m :: ms) => No (CertMismatch m)
```

**Severity:** Critical

---

### Policy 7: Filesystem Quota Enforcement

**Description:** No user or group may exceed their allocated disk quota.
Quota metadata must be consistent with actual block usage.

**Rationale:** Prevents resource exhaustion and detects quota metadata
corruption.

```idris
quotaPolicy : Policy
quotaPolicy state =
  let quotas = userQuotas state
      violations = filter quotaExceeded quotas
  in case violations of
       [] => Yes QuotasRespected
       (v :: vs) => No (QuotaViolation v)
```

**Severity:** Warning

---

### Policy 8: Audit Log Append-Only

**Description:** The audit log (`/var/log/audit/`) must be append-only.
No existing log entries may be modified or deleted.

**Rationale:** Ensures forensic integrity of audit trails. An attacker
who compromises a system often attempts to cover their tracks by modifying
audit logs.

```idris
auditAppendOnlyPolicy : Policy
auditAppendOnlyPolicy state =
  let logHashes = auditLogBlockHashes state
      previousHashes = auditLogBlockHashes (previousState state)
  in if isPrefixOf previousHashes logHashes
     then Yes AuditAppendOnly
     else No (AuditLogTampered (findFirstDivergence previousHashes logHashes))
```

**Severity:** Critical

---

### Policy 9: Mount Option Validation

**Description:** Security-sensitive mount options must be present on
appropriate filesystems (`nosuid` on `/tmp`, `noexec` on `/var/tmp`,
`nodev` on user-writable mounts).

**Rationale:** Missing mount options can enable privilege escalation
via SUID binaries on temporary filesystems.

```idris
mountOptionPolicy : Policy
mountOptionPolicy state =
  let mounts = activeMounts state
      violations = concatMap checkRequiredOptions mounts
  in case violations of
       [] => Yes MountOptionsValid
       (v :: vs) => No (MissingMountOption v)
```

**Severity:** Warning

---

### Policy 10: SUID/SGID Restriction

**Description:** Files with SUID or SGID bits set must be in a whitelist
of known-safe binaries. Any new SUID/SGID file triggers a violation.

**Rationale:** SUID/SGID binaries are the most common vector for local
privilege escalation.

```idris
suidRestrictionPolicy : Policy
suidRestrictionPolicy state =
  let suidFiles = filter hasSuidOrSgid (allFiles state)
      whitelist = approvedSuidBinaries state
      unknown = filter (\f => not (elem f whitelist)) suidFiles
  in case unknown of
       [] => Yes AllSuidApproved
       (f :: fs) => No (UnauthorisedSuid f)
```

**Severity:** Critical

---

## 4. Anti-Patterns: What Does NOT Belong in L4

The following are examples of policies that should **NEVER** be implemented
in L4. They violate the fundamental principle that L4 is for system integrity
only.

### Anti-Pattern 1: Spelling Enforcement

**BAD -- Do NOT implement this:**

```idris
-- ANTI-PATTERN: This does NOT belong in L4!
spellingPolicy : Policy
spellingPolicy state =
  let textFiles = filter isTextFile (allFiles state)
      misspelled = concatMap findSpellingErrors textFiles
  in case misspelled of
       [] => Yes NoSpellingErrors
       (e :: es) => No (SpellingError e)
```

**Why this is wrong:** Spelling is a content quality concern, not a system
integrity concern. A misspelled word in `/etc/motd` does not compromise
system security. Use a linter or CI/CD check instead.

---

### Anti-Pattern 2: Code Style Enforcement

**BAD -- Do NOT implement this:**

```idris
-- ANTI-PATTERN: This does NOT belong in L4!
codeStylePolicy : Policy
codeStylePolicy state =
  let sourceFiles = filter isSourceCode (allFiles state)
      styleViolations = concatMap checkIndentation sourceFiles
  in case styleViolations of
       [] => Yes CodeStyleCompliant
       (v :: vs) => No (StyleViolation v)
```

**Why this is wrong:** Code formatting is an aesthetic and maintainability
concern. Tabs vs. spaces does not affect system integrity. Use `.editorconfig`,
`prettier`, `rustfmt`, or equivalent tools.

---

### Anti-Pattern 3: Business Logic Validation

**BAD -- Do NOT implement this:**

```idris
-- ANTI-PATTERN: This does NOT belong in L4!
priceRangePolicy : Policy
priceRangePolicy state =
  let configFiles = filter isAppConfig (allFiles state)
      prices = extractPrices configFiles
      outOfRange = filter (\p => p < 0 || p > 10000) prices
  in case outOfRange of
       [] => Yes PricesValid
       (p :: ps) => No (PriceOutOfRange p)
```

**Why this is wrong:** Business rules about valid price ranges are
application-level concerns. A price of -1 might be a bug, but it does not
compromise the integrity of the filesystem or the operating system. Use
application-level validation.

---

## 5. Policy Composition

Policies can be composed using combinators:

```idris
-- All policies must pass
allOf : List Policy -> Policy
allOf policies state =
  let results = map (\p => p state) policies
  in if all isYes results
     then Yes (AllSatisfied results)
     else No (FirstFailure (findNo results))

-- At least one policy must pass
anyOf : List Policy -> Policy
anyOf policies state =
  let results = map (\p => p state) policies
  in if any isYes results
     then Yes (SomeSatisfied (findYes results))
     else No (NoneSatisfied results)

-- Negate a policy
negation : Policy -> Policy
negation policy state =
  case policy state of
    Yes prf => No (NegatedSatisfied prf)
    No contra => Yes (NegatedViolated contra)
```

## 6. Policy Lifecycle

1. **Definition:** A policy is written as an Idris2 function and type-checked.
2. **Registration:** The policy is added to the active policy set in the
   Ochrance configuration.
3. **Evaluation:** On each verification cycle, all active policies are
   evaluated against the current `VerifiedState`.
4. **Reporting:** Results are recorded in the `@policy` section of the
   A2ML attestation document.
5. **Remediation:** Critical violations may trigger L3 repair actions
   (e.g., restoring a tampered config from a verified snapshot).
6. **Retirement:** Policies can be deactivated but are never deleted
   from the audit trail.

---

## 7. Cross-References

| Document | Relevance |
|----------|-----------|
| `docs/ARCHITECTURE.md` | L4 layer definition and invariants |
| `docs/A2ML-SPEC.md` | `@policy` section format for recording evaluations |
| `docs/WHITEPAPER.md` | Formal treatment of policy decidability |
| `docs/THREAT-MODEL.md` | Threats that L4 policies are designed to mitigate |
