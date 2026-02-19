-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Types
|||
||| Abstract Syntax Tree types for the A2ML (AI-to-Machine Language) format.
|||
||| A2ML is the manifest format used by the Ochrance framework to describe
||| subsystem integrity constraints. It consists of four sections:
|||
|||   @manifest   — Metadata (name, version, author, description)
|||   @refs       — References to external resources and dependencies
|||   @attestation — Cryptographic attestation data (hashes, signatures)
|||   @policy     — Verification policy (mode, thresholds, schedules)
|||
||| This module defines the AST types produced by the parser and consumed
||| by the validator and serializer.

module Ochrance.A2ML.Types

%default total

--------------------------------------------------------------------------------
-- Token types (used by Lexer)
--------------------------------------------------------------------------------

||| Source location for error reporting.
public export
record SourceLoc where
  constructor MkLoc
  line   : Nat
  column : Nat

||| Show instance for source locations.
public export
Show SourceLoc where
  show loc = show loc.line ++ ":" ++ show loc.column

||| Token types produced by the A2ML lexer.
public export
data TokenKind : Type where
  ||| @manifest section header
  TK_MANIFEST    : TokenKind
  ||| @refs section header
  TK_REFS        : TokenKind
  ||| @attestation section header
  TK_ATTESTATION : TokenKind
  ||| @policy section header
  TK_POLICY      : TokenKind
  ||| Left brace '{'
  TK_LBRACE      : TokenKind
  ||| Right brace '}'
  TK_RBRACE      : TokenKind
  ||| Colon ':'
  TK_COLON       : TokenKind
  ||| Equals '='
  TK_EQUALS      : TokenKind
  ||| Identifier (field names, values)
  TK_IDENT       : String -> TokenKind
  ||| Quoted string literal
  TK_STRING      : String -> TokenKind
  ||| Hash literal (hex-encoded)
  TK_HASH        : String -> TokenKind
  ||| End of file
  TK_EOF         : TokenKind

||| A token with its source location.
public export
record Token where
  constructor MkToken
  kind : TokenKind
  loc  : SourceLoc

--------------------------------------------------------------------------------
-- Hash types
--------------------------------------------------------------------------------

||| Supported hash algorithms.
public export
data HashAlgo : Type where
  SHA256 : HashAlgo
  SHA384 : HashAlgo
  SHA512 : HashAlgo
  BLAKE3 : HashAlgo

||| Show instance for hash algorithms.
public export
Show HashAlgo where
  show SHA256 = "sha256"
  show SHA384 = "sha384"
  show SHA512 = "sha512"
  show BLAKE3 = "blake3"

||| Decidable equality for hash algorithms.
public export
Eq HashAlgo where
  SHA256 == SHA256 = True
  SHA384 == SHA384 = True
  SHA512 == SHA512 = True
  BLAKE3 == BLAKE3 = True
  _      == _      = False

||| A hash value with its algorithm.
public export
record Hash where
  constructor MkA2MLHash
  algo   : HashAlgo
  digest : String

--------------------------------------------------------------------------------
-- AST node types
--------------------------------------------------------------------------------

||| Key-value pair in a section.
public export
record Field where
  constructor MkField
  key   : String
  value : String
  loc   : SourceLoc

||| Reference entry in @refs section.
public export
record Ref where
  constructor MkRef
  name     : String
  target   : String
  refHash  : Maybe Hash
  loc      : SourceLoc

||| Attestation entry in @attestation section.
public export
record Attestation where
  constructor MkAttestation
  subject   : String
  hash      : Hash
  timestamp : Bits64
  signer    : Maybe String
  loc       : SourceLoc

||| Policy rule in @policy section.
public export
record PolicyRule where
  constructor MkPolicyRule
  name       : String
  mode       : String
  threshold  : Maybe Nat
  schedule   : Maybe String
  loc        : SourceLoc

--------------------------------------------------------------------------------
-- Sections
--------------------------------------------------------------------------------

||| The @manifest section — metadata about the subsystem.
public export
record ManifestSection where
  constructor MkManifestSection
  name        : String
  version     : String
  author      : String
  description : String
  fields      : List Field

||| The @refs section — external references.
public export
record RefsSection where
  constructor MkRefsSection
  refs : List Ref

||| The @attestation section — cryptographic attestation data.
public export
record AttestationSection where
  constructor MkAttestationSection
  attestations : List Attestation

||| The @policy section — verification policy rules.
public export
record PolicySection where
  constructor MkPolicySection
  rules : List PolicyRule

--------------------------------------------------------------------------------
-- Top-level Manifest
--------------------------------------------------------------------------------

||| A complete A2ML manifest comprising all four sections.
||| The manifest section is required; others are optional.
public export
record Manifest where
  constructor MkManifest
  manifest    : ManifestSection
  refs        : Maybe RefsSection
  attestation : Maybe AttestationSection
  policy      : Maybe PolicySection
