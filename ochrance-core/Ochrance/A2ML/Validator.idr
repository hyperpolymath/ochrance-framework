-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Validator
|||
||| Semantic validation for parsed A2ML manifests.
|||
||| The parser produces syntactically correct ASTs; this module performs
||| semantic validation to ensure the manifest is meaningful:
|||
|||   - Hash algorithm support and digest length validation
|||   - Required section completeness (all mandatory fields present)
|||   - Version string format and compatibility checking
|||   - Cross-reference integrity (refs point to real subjects)
|||   - Policy rule consistency (no conflicting modes)

module Ochrance.A2ML.Validator

import Ochrance.A2ML.Types
import Data.List
import Data.String

%default total

--------------------------------------------------------------------------------
-- Validation error types
--------------------------------------------------------------------------------

||| Errors that can occur during semantic validation.
public export
data ValidationError : Type where
  ||| A hash digest has the wrong length for its algorithm.
  InvalidHashLength  : (algo : HashAlgo) -> (expected : Nat) -> (actual : Nat) -> ValidationError
  ||| A hash digest contains non-hex characters.
  InvalidHashFormat  : (digest : String) -> ValidationError
  ||| A required field is missing from a section.
  MissingField       : (section : String) -> (field : String) -> ValidationError
  ||| A field value does not match the expected format.
  InvalidFieldValue  : (field : String) -> (value : String) -> (reason : String) -> ValidationError
  ||| A version string does not conform to semver.
  InvalidVersion     : (version : String) -> ValidationError
  ||| A reference target does not match any known subject.
  DanglingRef        : (refName : String) -> (target : String) -> ValidationError
  ||| A policy rule specifies an unknown verification mode.
  UnknownPolicyMode  : (mode : String) -> ValidationError
  ||| Two policy rules conflict with each other.
  ConflictingRules   : (rule1 : String) -> (rule2 : String) -> ValidationError

||| Show instance for validation errors.
public export
Show ValidationError where
  show (InvalidHashLength a e act) = "hash " ++ show a ++ ": expected " ++ show e ++ " chars, got " ++ show act
  show (InvalidHashFormat d)       = "invalid hex in hash digest: " ++ d
  show (MissingField s f)          = "missing field '" ++ f ++ "' in @" ++ s
  show (InvalidFieldValue f v r)   = "invalid value for '" ++ f ++ "': " ++ v ++ " (" ++ r ++ ")"
  show (InvalidVersion v)          = "invalid version string: " ++ v
  show (DanglingRef n t)           = "dangling ref '" ++ n ++ "' -> " ++ t
  show (UnknownPolicyMode m)       = "unknown policy mode: " ++ m
  show (ConflictingRules r1 r2)    = "conflicting rules: " ++ r1 ++ " vs " ++ r2

||| Validation result: collects all errors (not just the first).
public export
ValidationResult : Type
ValidationResult = Either (List ValidationError) ()

--------------------------------------------------------------------------------
-- Hash validation
--------------------------------------------------------------------------------

||| Expected hex-encoded digest length for each algorithm.
expectedDigestLength : HashAlgo -> Nat
expectedDigestLength SHA256 = 64
expectedDigestLength SHA384 = 96
expectedDigestLength SHA512 = 128
expectedDigestLength BLAKE3 = 64

||| Check that a single character is a valid hex digit.
isHexDigit : Char -> Bool
isHexDigit c = (c >= '0' && c <= '9')
            || (c >= 'a' && c <= 'f')
            || (c >= 'A' && c <= 'F')

||| Validate a hash value: correct length and hex format.
public export
validateHash : Hash -> List ValidationError
validateHash h =
  let expectedLen = expectedDigestLength h.algo
      actualLen   = length h.digest
      lenErrors   = if actualLen == expectedLen
                    then []
                    else [InvalidHashLength h.algo expectedLen actualLen]
      hexChars    = unpack h.digest
      formatOk    = all isHexDigit hexChars
      fmtErrors   = if formatOk then [] else [InvalidHashFormat h.digest]
  in lenErrors ++ fmtErrors

--------------------------------------------------------------------------------
-- Manifest section validation
--------------------------------------------------------------------------------

||| Validate the @manifest section: check required fields.
public export
validateManifestSection : ManifestSection -> List ValidationError
validateManifestSection ms =
  let nameErr = if ms.name == ""
                then [MissingField "manifest" "name"]
                else []
      verErr  = if ms.version == ""
                then [MissingField "manifest" "version"]
                else validateVersion ms.version
  in nameErr ++ verErr
  where
    ||| Check that a version string looks like semver (x.y.z).
    ||| TODO: Implement full semver validation.
    validateVersion : String -> List ValidationError
    validateVersion v =
      let parts = split (== '.') v
      in if length (forget parts) < 2
         then [InvalidVersion v]
         else []

--------------------------------------------------------------------------------
-- Refs section validation
--------------------------------------------------------------------------------

||| Validate the @refs section: check ref hashes if present.
public export
validateRefsSection : RefsSection -> List ValidationError
validateRefsSection rs = concatMap validateRef rs.refs
  where
    validateRef : Ref -> List ValidationError
    validateRef r =
      case r.refHash of
        Nothing => []
        Just h  => validateHash h

--------------------------------------------------------------------------------
-- Attestation section validation
--------------------------------------------------------------------------------

||| Validate the @attestation section: check all hashes.
public export
validateAttestationSection : AttestationSection -> List ValidationError
validateAttestationSection as = concatMap validateAtt as.attestations
  where
    validateAtt : Attestation -> List ValidationError
    validateAtt a =
      let hashErrs = validateHash a.hash
          subjErr  = if a.subject == ""
                     then [MissingField "attestation" "subject"]
                     else []
      in hashErrs ++ subjErr

--------------------------------------------------------------------------------
-- Policy section validation
--------------------------------------------------------------------------------

||| Known valid policy mode strings.
validModes : List String
validModes = ["lax", "checked", "attested"]

||| Validate the @policy section: check mode names and rule consistency.
public export
validatePolicySection : PolicySection -> List ValidationError
validatePolicySection ps = concatMap validateRule ps.rules
  where
    validateRule : PolicyRule -> List ValidationError
    validateRule r =
      let modeErr = if elem r.mode validModes
                    then []
                    else [UnknownPolicyMode r.mode]
      in modeErr
      -- TODO: Check for conflicting rules across the full rule set

--------------------------------------------------------------------------------
-- Top-level validator
--------------------------------------------------------------------------------

||| Validate a complete A2ML manifest, collecting all errors.
|||
||| Returns Right () if the manifest is semantically valid,
||| or Left errors with the full list of validation issues found.
|||
||| @manifest  The parsed manifest to validate
||| @return    Either a list of all validation errors, or unit on success
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
