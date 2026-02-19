<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Rebrand Summary: Sentinel to Ochrance

> **Date:** 2026-02-19
> **Status:** Complete
> **Decision type:** Permanent, irreversible

## 1. Rationale

The project was originally named "Sentinel" during early development. This
name was changed to "Ochrance" for the following reasons:

### 1.1 Distinctiveness

"Sentinel" is an extremely common name in the software security space:

- **Microsoft Sentinel** (Azure Sentinel) -- SIEM platform, millions of users.
- **HashiCorp Sentinel** -- Policy-as-code framework.
- **SentinelOne** -- Endpoint detection and response (publicly traded company).
- **Redis Sentinel** -- High availability for Redis.
- Dozens of other projects, libraries, and products.

Using "Sentinel" would create confusion in search results, package registries,
academic citations, and casual conversation. A researcher searching for
"Sentinel filesystem verification" would be buried under Microsoft and
HashiCorp results.

### 1.2 Searchability

"Ochrance" is globally unique in the software namespace. A search for
"Ochrance" returns zero competing results. This provides:

- Unambiguous search engine results.
- Clean package registry namespaces (crates.io, npm, PyPI, Hex.pm).
- Distinct academic citation identity.
- Clear trademark path if needed.

### 1.3 Cultural Recognition

The name carries meaningful cultural weight: it is a Czech word meaning
"protector," "defender," or "guardian." This resonates with the project's
purpose of protecting filesystem integrity.

### 1.4 International Philosophy

The hyperpolymath project portfolio draws from multiple linguistic and
cultural traditions. Using a Czech word reflects the internationalist
philosophy of the project, alongside names from Greek (ECHIDNA, Ephapax),
Latin, and other traditions.

---

## 2. Etymology

### 2.1 Czech Origin

**Ochrance** (Czech: *ochrance*)

- **Root word:** *ochrana* -- protection, safeguard, defence
- **Derived form:** *ochrance* -- protector, defender, guardian (agent noun)
- **Literal meaning:** "one who protects" or "the protecting one"

### 2.2 Pronunciation

| Notation | Value |
|----------|-------|
| IPA | /ˈoxraːnt͡sɛ/ |
| Approximate English | "OKH-rahn-tseh" |
| Stress | First syllable |
| `ch` | Voiceless velar fricative (like Scottish "loch") |
| `c` | /t͡s/ affricate (like "ts" in "cats") |
| `e` | Open-mid front unrounded vowel (like "e" in "bet") |

### 2.3 Diacritic

The full Czech form uses a haček (caron) on the `a`: **Ochrance**.

In practice, the haček is omitted in the repository name and code identifiers
because:

- File system paths and URLs should be ASCII-safe.
- Package registries may not handle diacritics consistently.
- Terminal emulators vary in Unicode rendering quality.

The diacritic IS used in prose, documentation, and academic writing to
respect the Czech orthography.

---

## 3. Naming Conventions

### 3.1 Where to Use Each Form

| Context | Form | Example |
|---------|------|---------|
| Repository name | `ochrance-framework` | `github.com/hyperpolymath/ochrance-framework` |
| Directory paths | `ochrance-framework` | `/var/mnt/eclipse/repos/ochrance-framework/` |
| Package names | `ochrance` | `ochrance-core`, `ochrance-shim` |
| Code identifiers | `Ochrance` | `OchranceConfig`, `OchranceVerifier` |
| Module names | `Ochrance` | `Ochrance.Core`, `Ochrance.Merkle` |
| Prose (docs) | Ochrance | "The Ochrance framework verifies..." |
| Academic papers | Ochrance | "We present Ochrance, a neurosymbolic..." |
| Casual speech | Ochrance | "Ochrance detected corruption in block 42." |
| CLI binary | `ochrance` | `ochrance verify /dev/nvme0n1` |

### 3.2 Crate/Package Names

| Registry | Package Name |
|----------|-------------|
| crates.io (Rust components) | `ochrance` |
| Idris2 packages | `ochrance` |
| Hex.pm (Elixir/ECHIDNA) | `ochrance` |
| Container images | `ochrance-framework` |

### 3.3 Academic Citation

```bibtex
@mastersthesis{jewell2026ochrance,
  author  = {Jewell, Jonathan D.A.},
  title   = {Neurosymbolic Filesystem Verification:
             Integrating {ECHIDNA} with {Ochr\'{a}nce}},
  school  = {The Open University},
  year    = {2026},
  type    = {MSc thesis}
}
```

---

## 4. Migration Checklist

The following changes were made during the rebrand:

| Item | Old Value | New Value | Status |
|------|-----------|-----------|--------|
| Repository name | `sentinel-framework` | `ochrance-framework` | Complete |
| README title | "Sentinel Framework" | "Ochrance Framework" | Complete |
| Package name | `sentinel` | `ochrance` | Complete |
| Module prefix | `Sentinel.` | `Ochrance.` | Complete |
| C library name | `libsentinel_shim.so` | `libochrance_shim.so` | Complete |
| Header guard | `SENTINEL_SHIM_H` | `OCHRANCE_SHIM_H` | Complete |
| CLI binary | `sentinel` | `ochrance` | Complete |
| Config directory | `~/.config/sentinel/` | `~/.config/ochrance/` | Complete |
| Documentation references | "Sentinel" | "Ochrance" | Complete |
| White paper title | "...with Sentinel" | "...with Ochrance" | Complete |
| A2ML producer field | `sentinel-framework` | `ochrance-framework` | Complete |
| CI/CD references | `sentinel` | `ochrance` | Complete |

---

## 5. Legacy References

If you encounter references to "Sentinel" in the codebase, git history,
or external documents, they refer to this project under its previous name.
The rebrand is **permanent and irreversible**. Do not revert to "Sentinel."

Historical git commits before the rebrand may contain "Sentinel" in commit
messages and file contents. These are preserved in the git history for
archaeological purposes but should not be used as a basis for current naming.

---

## 6. Cross-References

| Document | Relevance |
|----------|-----------|
| `docs/WHITEPAPER.md` | Uses "Ochrance" throughout |
| `docs/ARCHITECTURE.md` | Framework and module naming |
| `README.adoc` | Project introduction |
| `TOPOLOGY.md` | Architecture diagram labels |
