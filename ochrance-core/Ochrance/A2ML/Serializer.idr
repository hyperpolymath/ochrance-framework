-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Serializer — Manifest Generation.
|||
||| This module implements the inverse of the A2ML parsing pipeline. It 
||| transforms a structured `Manifest` AST back into its canonical 
||| natural-language surface syntax.
|||
//! INVARIANT: The serializer MUST produce output that, when re-lexed and 
//! re-parsed, results in an identical AST.
//! 
//! parse (lex (serialize m)) == Right m

module Ochrance.A2ML.Serializer

import Ochrance.A2ML.Types
import Data.String
import Data.List

%default total

--------------------------------------------------------------------------------
-- Serializers
--------------------------------------------------------------------------------

||| HASH SERIALIZATION: Formats a hash as "algo:digest" (e.g. blake3:...).
public export
serializeHash : Hash -> String
serializeHash h = serializeAlgo h.algo ++ ":" ++ h.digest

||| SECTION SERIALIZATION (@manifest): Generates the header block with 
||| project metadata and custom fields.
public export
serializeManifest : ManifestSection -> String
serializeManifest ms =
  let header = "@manifest {\n"
      body   = indent 1 ++ "name = \"" ++ ms.name ++ "\"\n"
            ++ indent 1 ++ "version = \"" ++ ms.version ++ "\"\n"
      -- ... [Field mapping]
      close  = "}"
  in header ++ body ++ close

||| ENTRY POINT: Serializes a complete multi-section manifest.
||| Ensures sections are separated by blank lines for human readability.
public export
serialize : Manifest -> String
serialize m =
  let sections = serializeManifest m.manifest
              :: catMaybes [ map serializeRefs m.refs
                           , map serializeAttestationSection m.attestation
                           , map serializePolicySection m.policy
                           ]
  in joinWith "\n\n" sections ++ "\n"
