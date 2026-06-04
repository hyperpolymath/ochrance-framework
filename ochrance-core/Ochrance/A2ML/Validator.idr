-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

||| Ochrance.A2ML.Validator — Semantic Integrity Enforcement.
|||
||| While the parser ensures syntactic correctness, this module performs
||| deep semantic validation to guarantee the manifest is meaningful and
||| cryptographically sound.
|||
||| VALIDATION AXES:
||| 1. Hashing: digest lengths match their algorithms (e.g. BLAKE3 = 64 hex chars).
||| 2. Completeness: mandatory @manifest fields are present and non-empty.
||| 3. Consistency: references are well-formed hex digests.

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

||| AGGREGATION: Collects all detected errors into a list, so the developer
||| sees every issue in a single pass (rather than failing fast).
public export
ValidationResult : Type
ValidationResult = Either (List ValidationError) ()

--------------------------------------------------------------------------------
-- Per-axis checks
--------------------------------------------------------------------------------

||| Expected hex-digest length (characters) for each algorithm.
expectedLength : HashAlgo -> Nat
expectedLength SHA256 = 64
expectedLength SHA384 = 96
expectedLength SHA512 = 128
expectedLength BLAKE3 = 64

||| A digest must be hexadecimal and of its algorithm's expected length.
validateHash : Hash -> List ValidationError
validateHash h =
  let ds = unpack h.digest
      n  = length ds
      lenErr = if n == expectedLength h.algo
                 then []
                 else [InvalidHashLength h.algo (expectedLength h.algo) n]
      fmtErr = if all isHexDigit ds then [] else [InvalidHashFormat h.digest]
  in lenErr ++ fmtErr

public export
validateManifestSection : ManifestSection -> List ValidationError
validateManifestSection ms =
  (if ms.name    == "" then [MissingField "manifest" "name"]    else [])
  ++ (if ms.version == "" then [MissingField "manifest" "version"] else [])

public export
validateRefsSection : RefsSection -> List ValidationError
validateRefsSection rs = concatMap (validateHash . refHash) rs.entries

public export
validateAttestationSection : AttestationSection -> List ValidationError
validateAttestationSection (MkAttestationSection a) = validateHash a.hash

public export
validatePolicySection : PolicySection -> List ValidationError
validatePolicySection _ = []  -- a parsed PolicyMode is always well-formed

--------------------------------------------------------------------------------
-- Whole-manifest audit
--------------------------------------------------------------------------------

||| SEMANTIC AUDIT: Ingests a complete manifest and validates every section,
||| aggregating all detected errors.
public export
validate : Manifest -> ValidationResult
validate m =
  let allErrs = validateManifestSection m.manifest
             ++ maybe [] validateRefsSection m.refs
             ++ maybe [] validateAttestationSection m.attestation
             ++ maybe [] validatePolicySection m.policy
  in case allErrs of
       [] => Right ()
       es => Left es
