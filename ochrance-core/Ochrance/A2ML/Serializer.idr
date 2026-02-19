-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Serializer
|||
||| Serializer for converting A2ML Manifest ASTs back to text format.
|||
||| Provides both compact and pretty-printed output. The serializer
||| is the inverse of the lexer+parser pipeline: for any valid manifest m,
|||   parse (lex (serialize m)) = Right m
|||
||| This round-trip property should be verified by tests (not proven here,
||| as it depends on the parser implementation being complete).

module Ochrance.A2ML.Serializer

import Ochrance.A2ML.Types
import Data.String
import Data.List

%default total

--------------------------------------------------------------------------------
-- Indentation helpers
--------------------------------------------------------------------------------

||| Generate indentation string of given depth (2 spaces per level).
indent : Nat -> String
indent Z     = ""
indent (S k) = "  " ++ indent k

||| Join a list of strings with a separator.
joinWith : String -> List String -> String
joinWith sep []        = ""
joinWith sep [x]       = x
joinWith sep (x :: xs) = x ++ sep ++ joinWith sep xs

--------------------------------------------------------------------------------
-- Hash serialization
--------------------------------------------------------------------------------

||| Serialize a hash algorithm name.
public export
serializeAlgo : HashAlgo -> String
serializeAlgo SHA256 = "sha256"
serializeAlgo SHA384 = "sha384"
serializeAlgo SHA512 = "sha512"
serializeAlgo BLAKE3 = "blake3"

||| Serialize a hash value as "algo:digest".
public export
serializeHash : Hash -> String
serializeHash h = serializeAlgo h.algo ++ ":" ++ h.digest

--------------------------------------------------------------------------------
-- Field serialization
--------------------------------------------------------------------------------

||| Serialize a key-value field.
serializeField : Nat -> Field -> String
serializeField depth f =
  indent depth ++ f.key ++ " = \"" ++ f.value ++ "\""

--------------------------------------------------------------------------------
-- Section serialization
--------------------------------------------------------------------------------

||| Serialize the @manifest section.
public export
serializeManifest : ManifestSection -> String
serializeManifest ms =
  let header = "@manifest {\n"
      name   = indent 1 ++ "name = \"" ++ ms.name ++ "\"\n"
      ver    = indent 1 ++ "version = \"" ++ ms.version ++ "\"\n"
      author = indent 1 ++ "author = \"" ++ ms.author ++ "\"\n"
      desc   = indent 1 ++ "description = \"" ++ ms.description ++ "\"\n"
      fields = joinWith "\n" (map (serializeField 1) ms.fields)
      fieldsStr = if fields == "" then "" else fields ++ "\n"
      close  = "}"
  in header ++ name ++ ver ++ author ++ desc ++ fieldsStr ++ close

||| Serialize a single reference entry.
serializeRef : Ref -> String
serializeRef r =
  let base = indent 1 ++ r.name ++ " : \"" ++ r.target ++ "\""
  in case r.refHash of
       Nothing => base
       Just h  => base ++ " #" ++ h.digest

||| Serialize the @refs section.
public export
serializeRefs : RefsSection -> String
serializeRefs rs =
  let header = "@refs {\n"
      entries = joinWith "\n" (map serializeRef rs.refs)
      close  = "\n}"
  in header ++ entries ++ close

||| Serialize a single attestation entry.
serializeAttestation : Attestation -> String
serializeAttestation a =
  let base = indent 1 ++ a.subject ++ " : " ++ serializeHash a.hash
                      ++ " @ " ++ show a.timestamp
  in case a.signer of
       Nothing => base
       Just s  => base ++ " [" ++ s ++ "]"

||| Serialize the @attestation section.
public export
serializeAttestationSection : AttestationSection -> String
serializeAttestationSection as' =
  let header = "@attestation {\n"
      entries = joinWith "\n" (map serializeAttestation as'.attestations)
      close  = "\n}"
  in header ++ entries ++ close

||| Serialize a single policy rule.
serializePolicyRule : PolicyRule -> String
serializePolicyRule r =
  let base = indent 1 ++ r.name ++ " = " ++ r.mode
      withThreshold = case r.threshold of
                        Nothing => base
                        Just t  => base ++ " threshold=" ++ show t
      withSchedule  = case r.schedule of
                        Nothing => withThreshold
                        Just s  => withThreshold ++ " schedule=\"" ++ s ++ "\""
  in withSchedule

||| Serialize the @policy section.
public export
serializePolicySection : PolicySection -> String
serializePolicySection ps =
  let header = "@policy {\n"
      entries = joinWith "\n" (map serializePolicyRule ps.rules)
      close  = "\n}"
  in header ++ entries ++ close

--------------------------------------------------------------------------------
-- Top-level serializer
--------------------------------------------------------------------------------

||| Serialize a complete Manifest to A2ML text format.
|||
||| Sections are separated by blank lines. Optional sections are
||| only included if present.
|||
||| @manifest  The Manifest AST to serialize
||| @return    The A2ML text representation
public export
serialize : Manifest -> String
serialize m =
  let sections = serializeManifest m.manifest
              :: catMaybes [ map serializeRefs m.refs
                           , map serializeAttestationSection m.attestation
                           , map serializePolicySection m.policy
                           ]
  in joinWith "\n\n" sections ++ "\n"
  where
    catMaybes : List (Maybe String) -> List String
    catMaybes []              = []
    catMaybes (Nothing :: xs) = catMaybes xs
    catMaybes (Just x :: xs)  = x :: catMaybes xs

||| Compact serialization: no extra whitespace or blank lines.
|||
||| TODO: Implement compact format for machine-to-machine transfer.
public export
serializeCompact : Manifest -> String
serializeCompact = serialize  -- For now, same as pretty. TODO: strip whitespace.
