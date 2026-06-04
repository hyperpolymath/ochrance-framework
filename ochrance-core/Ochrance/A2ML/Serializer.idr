-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

||| Ochrance.A2ML.Serializer — Manifest Generation.
|||
||| This module implements the inverse of the A2ML parsing pipeline. It
||| transforms a structured `Manifest` AST back into its canonical
||| natural-language surface syntax.
|||
||| INVARIANT: the serializer produces output that, when re-lexed and
||| re-parsed, yields an identical AST: parse (lex (serialize m)) == Right m.

module Ochrance.A2ML.Serializer

import Ochrance.A2ML.Types
import Data.String
import Data.List

%default total

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

||| One indentation level is two spaces.
indent : Nat -> String
indent n = pack (replicate (n * 2) ' ')

||| Render a hash algorithm as its canonical lowercase tag.
public export
serializeAlgo : HashAlgo -> String
serializeAlgo SHA256 = "sha256"
serializeAlgo SHA384 = "sha384"
serializeAlgo SHA512 = "sha512"
serializeAlgo BLAKE3 = "blake3"

||| Render a policy mode as its canonical lowercase tag.
serializeMode : PolicyMode -> String
serializeMode PolicyLax      = "lax"
serializeMode PolicyChecked  = "checked"
serializeMode PolicyAttested = "attested"

--------------------------------------------------------------------------------
-- Section Serializers
--------------------------------------------------------------------------------

||| HASH SERIALIZATION: Formats a hash as "algo:digest" (e.g. blake3:...).
public export
serializeHash : Hash -> String
serializeHash h = serializeAlgo h.algo ++ ":" ++ h.digest

||| SECTION (@manifest): the project metadata header.
public export
serializeManifest : ManifestSection -> String
serializeManifest ms =
  "@manifest {\n"
  ++ indent 1 ++ "name = \""    ++ ms.name    ++ "\"\n"
  ++ indent 1 ++ "version = \"" ++ ms.version ++ "\"\n"
  ++ "}"

||| SECTION (@refs): one `name : algo:digest` line per reference.
public export
serializeRefs : RefsSection -> String
serializeRefs rs =
  "@refs {\n" ++ concat (map refLine rs.entries) ++ "}"
  where
    refLine : Ref -> String
    refLine r = indent 1 ++ r.refName ++ " : " ++ serializeHash r.refHash ++ "\n"

||| SECTION (@attestation): the signed claim.
public export
serializeAttestationSection : AttestationSection -> String
serializeAttestationSection (MkAttestationSection a) =
  "@attestation {\n"
  ++ indent 1 ++ "subject = \"" ++ a.subject ++ "\"\n"
  ++ indent 1 ++ "hash = "      ++ serializeHash a.hash ++ "\n"
  ++ indent 1 ++ "timestamp = " ++ show a.timestamp ++ "\n"
  ++ maybe "" (\s => indent 1 ++ "signer = \"" ++ s ++ "\"\n") a.signer
  ++ "}"

||| SECTION (@policy): the enforcement rules.
public export
serializePolicySection : PolicySection -> String
serializePolicySection ps =
  "@policy {\n"
  ++ indent 1 ++ "mode = \"" ++ serializeMode ps.mode ++ "\"\n"
  ++ indent 1 ++ "require_sig = " ++ (if ps.requireSig then "true" else "false") ++ "\n"
  ++ "}"

--------------------------------------------------------------------------------
-- Entry Point
--------------------------------------------------------------------------------

||| ENTRY POINT: Serializes a complete multi-section manifest, separating
||| sections with blank lines for human readability.
public export
serialize : Manifest -> String
serialize m =
  let sections = serializeManifest m.manifest
              :: catMaybes [ map serializeRefs m.refs
                           , map serializeAttestationSection m.attestation
                           , map serializePolicySection m.policy
                           ]
  in concat (intersperse "\n\n" sections) ++ "\n"
