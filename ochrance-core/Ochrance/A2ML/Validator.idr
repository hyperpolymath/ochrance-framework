-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Validator — Semantic Integrity Enforcement.
|||
||| While the parser ensures syntactic correctness, this module performs 
||| deep semantic validation to guarantee the manifest is meaningful and 
||| cryptographically sound.
|||
||| VALIDATION AXES:
||| 1. **Hashing**: Verifies that digest lengths match their algorithms 
|||    (e.g. BLAKE3 must be 64 hex characters).
||| 2. **Completeness**: Ensures mandatory fields in the `@manifest` 
//!    header are present and non-empty.
||| 3. **Consistency**: Checks for dangling references and conflicting 
//!    policy rules.

module Ochrance.A2ML.Validator

import Ochrance.A2ML.Types
import Data.List
import Data.String

%default total

--------------------------------------------------------------------------------
-- Error Model
--------------------------------------------------------------------------------

||| VALIDATION ERROR: Specific semantic violations.
public export
data ValidationError : Type where
  InvalidHashLength  : (algo : HashAlgo) -> (expected, actual : Nat) -> ValidationError
  InvalidHashFormat  : (digest : String) -> ValidationError
  MissingField       : (section, field : String) -> ValidationError
  InvalidVersion     : (version : String) -> ValidationError
  UnknownPolicyMode  : (mode : String) -> ValidationError

||| AGGREGATION: Collects all detected errors into a list. 
||| This avoids the "fail-fast" problem, allowing the developer to see 
||| all issues in a single pass.
public export
ValidationResult : Type
ValidationResult = Either (List ValidationError) ()

--------------------------------------------------------------------------------
-- Validation Logic
--------------------------------------------------------------------------------

||| SEMANTIC AUDIT: Ingests a complete manifest and recursively validates 
||| every section.
public export
validate : Manifest -> ValidationResult
validate m =
  let manifestErrs    = validateManifestSection m.manifest
      refsErrs        = maybe [] validateRefsSection m.refs
      attestationErrs = maybe [] validateAttestationSection m.attestation
      policyErrs      = maybe [] validatePolicySection m.policy
      allErrs         = manifestErrs ++ refsErrs ++ attestationErrs ++ policyErrs
  in case allErrs of
       [] => Right ()
       es => Left es
