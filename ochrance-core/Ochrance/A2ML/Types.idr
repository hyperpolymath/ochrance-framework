-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Types — Manifest Abstract Syntax Tree.
|||
||| This module defines the formal grammar components for the A2ML 
||| (AI-to-Machine Language) format. It provides the types used by 
||| the Lexer, Parser, and Validator to represent system integrity 
||| constraints.

module Ochrance.A2ML.Types

%default total

--------------------------------------------------------------------------------
-- Lexical Tokens
--------------------------------------------------------------------------------

||| TOKEN KIND: Atomic semantic units produced by the lexer.
public export
data TokenKind : Type where
  TK_MANIFEST    : TokenKind -- @manifest
  TK_REFS        : TokenKind -- @refs
  TK_ATTESTATION : TokenKind -- @attestation
  TK_POLICY      : TokenKind -- @policy
  TK_IDENT       : String -> TokenKind
  TK_STRING      : String -> TokenKind
  TK_HASH        : String -> TokenKind
  TK_EOF         : TokenKind

--------------------------------------------------------------------------------
-- Integrity Models
--------------------------------------------------------------------------------

||| HASH ALGORITHM: Supported collision-resistant functions.
public export
data HashAlgo : Type where
  SHA256, SHA384, SHA512, BLAKE3 : HashAlgo

||| HASH DIGEST: A coupled algorithm and hex-encoded value.
public export
record Hash where
  constructor MkA2MLHash
  algo   : HashAlgo
  digest : String

--------------------------------------------------------------------------------
-- AST Nodes
--------------------------------------------------------------------------------

||| ATTESTATION: A verified claim about a subject at a specific time.
public export
record Attestation where
  constructor MkAttestation
  subject   : String
  hash      : Hash
  timestamp : Bits64
  signer    : Maybe String

||| MANIFEST: The complete multi-section integrity specification.
public export
record Manifest where
  constructor MkManifest
  manifest    : ManifestSection
  refs        : Maybe RefsSection
  attestation : Maybe AttestationSection
  policy      : Maybe PolicySection
