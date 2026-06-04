-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Ochrance.A2ML.Parser — High-Assurance Manifest Parsing.
|||
||| This module implements a total, recursive-descent parser for the A2ML
||| format.
|||
||| TOTALITY GUARANTEE: section dispatch is driven by a "fuel" parameter
||| (initialised to the token count) that strictly decreases on each step,
||| while the `@refs` body recurses structurally on the token list. Neither
||| can loop forever.

module Ochrance.A2ML.Parser

import Ochrance.A2ML.Types
import Data.List
import Data.String

%default total

--------------------------------------------------------------------------------
-- Error Diagnostics
--------------------------------------------------------------------------------

||| PARSE ERROR: Provides precise structural context for failures.
public export
data ParseError : Type where
  ExpectedToken    : (expected, got : String) -> (loc : SourceLoc) -> ParseError
  UnexpectedEOF    : (context : String) -> ParseError
  DuplicateSection : (section : String) -> (loc : SourceLoc) -> ParseError
  MissingRequired  : (section : String) -> ParseError
  MalformedHash    : (raw : String) -> (loc : SourceLoc) -> ParseError

--------------------------------------------------------------------------------
-- Parser State
--------------------------------------------------------------------------------

public export
record ParserState where
  constructor MkParserState
  tokens : List Token

||| Look at the next token kind without consuming it.
peek : ParserState -> Maybe TokenKind
peek ps = case ps.tokens of
  []       => Nothing
  (t :: _) => Just t.kind

headLoc : ParserState -> SourceLoc
headLoc ps = case ps.tokens of
  []       => MkSourceLoc 0 0
  (t :: _) => t.loc

||| Accumulates the sections seen so far.
record SectionAccum where
  constructor MkSectionAccum
  manifestSec    : Maybe ManifestSection
  refsSec        : Maybe RefsSection
  attestationSec : Maybe AttestationSection
  policySec      : Maybe PolicySection

emptyAccum : SectionAccum
emptyAccum = MkSectionAccum Nothing Nothing Nothing Nothing

--------------------------------------------------------------------------------
-- Low-level consumers
--------------------------------------------------------------------------------

||| A human-readable name for a token kind (for error messages).
tokenName : TokenKind -> String
tokenName TK_MANIFEST    = "@manifest"
tokenName TK_REFS        = "@refs"
tokenName TK_ATTESTATION = "@attestation"
tokenName TK_POLICY      = "@policy"
tokenName (TK_IDENT s)   = "identifier '" ++ s ++ "'"
tokenName (TK_STRING _)  = "string"
tokenName (TK_HASH _)    = "hash"
tokenName (TK_NUMBER _)  = "number"
tokenName (TK_BOOL _)    = "bool"
tokenName TK_LBRACE      = "'{'"
tokenName TK_RBRACE      = "'}'"
tokenName TK_COLON       = "':'"
tokenName TK_EQUALS      = "'='"
tokenName TK_EOF         = "<eof>"

||| Consume a token whose kind equals `expected`.
eat : (expected : TokenKind) -> (what : String) -> ParserState -> Either ParseError ParserState
eat _ what (MkParserState []) = Left (UnexpectedEOF what)
eat expected what (MkParserState (t :: ts)) =
  if expected == t.kind
    then Right (MkParserState ts)
    else Left (ExpectedToken what (tokenName t.kind) t.loc)

||| Parse "algo:digest" into a `Hash`.
parseHashStr : String -> Maybe Hash
parseHashStr s = case break (== ':') (unpack s) of
  (algoChars, ':' :: digestChars) =>
    map (\a => MkA2MLHash a (pack digestChars)) (parseAlgo (pack algoChars))
  _ => Nothing
  where
    parseAlgo : String -> Maybe HashAlgo
    parseAlgo "sha256" = Just SHA256
    parseAlgo "sha384" = Just SHA384
    parseAlgo "sha512" = Just SHA512
    parseAlgo "blake3" = Just BLAKE3
    parseAlgo _        = Nothing

||| `key = STRING`.
stringField : (key : String) -> ParserState -> Either ParseError (String, ParserState)
stringField key ps = do
  ps1 <- eat (TK_IDENT key) (key ++ " field") ps
  ps2 <- eat TK_EQUALS "'='" ps1
  case ps2.tokens of
    (MkToken (TK_STRING s) _ :: ts) => Right (s, MkParserState ts)
    (t :: _) => Left (ExpectedToken "string value" (tokenName t.kind) t.loc)
    []       => Left (UnexpectedEOF (key ++ " value"))

||| `key = NUMBER`.
numberField : (key : String) -> ParserState -> Either ParseError (Nat, ParserState)
numberField key ps = do
  ps1 <- eat (TK_IDENT key) (key ++ " field") ps
  ps2 <- eat TK_EQUALS "'='" ps1
  case ps2.tokens of
    (MkToken (TK_NUMBER n) _ :: ts) => Right (n, MkParserState ts)
    (t :: _) => Left (ExpectedToken "number value" (tokenName t.kind) t.loc)
    []       => Left (UnexpectedEOF (key ++ " value"))

||| `key = BOOL`.
boolField : (key : String) -> ParserState -> Either ParseError (Bool, ParserState)
boolField key ps = do
  ps1 <- eat (TK_IDENT key) (key ++ " field") ps
  ps2 <- eat TK_EQUALS "'='" ps1
  case ps2.tokens of
    (MkToken (TK_BOOL b) _ :: ts) => Right (b, MkParserState ts)
    (t :: _) => Left (ExpectedToken "boolean value" (tokenName t.kind) t.loc)
    []       => Left (UnexpectedEOF (key ++ " value"))

||| `key = HASH`.
hashField : (key : String) -> ParserState -> Either ParseError (Hash, ParserState)
hashField key ps = do
  ps1 <- eat (TK_IDENT key) (key ++ " field") ps
  ps2 <- eat TK_EQUALS "'='" ps1
  case ps2.tokens of
    (MkToken (TK_HASH raw) loc :: ts) => case parseHashStr raw of
      Just h  => Right (h, MkParserState ts)
      Nothing => Left (MalformedHash raw loc)
    (t :: _) => Left (ExpectedToken "hash value" (tokenName t.kind) t.loc)
    []       => Left (UnexpectedEOF (key ++ " value"))

--------------------------------------------------------------------------------
-- Section bodies
--------------------------------------------------------------------------------

parseManifestSec : ParserState -> Either ParseError (ManifestSection, ParserState)
parseManifestSec ps = do
  ps1 <- eat TK_MANIFEST "@manifest" ps
  ps2 <- eat TK_LBRACE "'{'" ps1
  (name, ps3)    <- stringField "name" ps2
  (version, ps4) <- stringField "version" ps3
  ps5 <- eat TK_RBRACE "'}'" ps4
  Right (MkManifestSection name version, ps5)

||| Structural recursion on the token list: each accepted ref consumes three
||| tokens (IDENT COLON HASH), so the argument strictly shrinks.
parseRefEntries : List Token -> Either ParseError (List Ref, List Token)
parseRefEntries [] = Left (UnexpectedEOF "@refs body")
parseRefEntries (MkToken TK_RBRACE _ :: ts) = Right ([], ts)
parseRefEntries (MkToken (TK_IDENT nm) _ :: MkToken TK_COLON _ :: MkToken (TK_HASH raw) loc :: ts) =
  case parseHashStr raw of
    Nothing => Left (MalformedHash raw loc)
    Just h  => case parseRefEntries ts of
      Left e            => Left e
      Right (rest, ts') => Right (MkRef nm h :: rest, ts')
parseRefEntries (t :: _) = Left (ExpectedToken "reference or '}'" (tokenName t.kind) t.loc)

parseRefsSec : ParserState -> Either ParseError (RefsSection, ParserState)
parseRefsSec ps = do
  ps1 <- eat TK_REFS "@refs" ps
  ps2 <- eat TK_LBRACE "'{'" ps1
  case parseRefEntries ps2.tokens of
    Left e             => Left e
    Right (refs, rest) => Right (MkRefsSection refs, MkParserState rest)

parseAttestationSec : ParserState -> Either ParseError (AttestationSection, ParserState)
parseAttestationSec ps = do
  ps1 <- eat TK_ATTESTATION "@attestation" ps
  ps2 <- eat TK_LBRACE "'{'" ps1
  (subject, ps3) <- stringField "subject" ps2
  (h, ps4)       <- hashField "hash" ps3
  (ts, ps5)      <- numberField "timestamp" ps4
  (signer, ps6)  <- optionalSigner ps5
  ps7 <- eat TK_RBRACE "'}'" ps6
  Right (MkAttestationSection (MkAttestation subject h (cast ts) signer), ps7)
  where
    optionalSigner : ParserState -> Either ParseError (Maybe String, ParserState)
    optionalSigner st = case peek st of
      Just (TK_IDENT "signer") => do
        (s, st') <- stringField "signer" st
        Right (Just s, st')
      _ => Right (Nothing, st)

parsePolicySec : ParserState -> Either ParseError (PolicySection, ParserState)
parsePolicySec ps = do
  ps1 <- eat TK_POLICY "@policy" ps
  ps2 <- eat TK_LBRACE "'{'" ps1
  (modeStr, ps3) <- stringField "mode" ps2
  case parseMode modeStr of
    Nothing   => Left (ExpectedToken "policy mode (lax|checked|attested)" modeStr (headLoc ps2))
    Just mode => do
      (requireSig, ps4) <- boolField "require_sig" ps3
      ps5 <- eat TK_RBRACE "'}'" ps4
      Right (MkPolicySection mode requireSig, ps5)
  where
    parseMode : String -> Maybe PolicyMode
    parseMode "lax"      = Just PolicyLax
    parseMode "checked"  = Just PolicyChecked
    parseMode "attested" = Just PolicyAttested
    parseMode _          = Nothing

--------------------------------------------------------------------------------
-- Parsing Engine
--------------------------------------------------------------------------------

||| SECTION DISPATCH: Iteratively parses top-level A2ML directives. Fuel-bounded
||| for totality; each accepted section also advances the token stream.
parseSections : (fuel : Nat)
             -> ParserState
             -> SectionAccum
             -> Either ParseError (SectionAccum, ParserState)
parseSections Z     ps acc = Right (acc, ps)
parseSections (S k) ps acc =
  case peek ps of
    Just TK_MANIFEST => case parseManifestSec ps of
      Left e          => Left e
      Right (ms, ps') => parseSections k ps' ({ manifestSec := Just ms } acc)
    Just TK_REFS => case parseRefsSec ps of
      Left e          => Left e
      Right (rs, ps') => parseSections k ps' ({ refsSec := Just rs } acc)
    Just TK_ATTESTATION => case parseAttestationSec ps of
      Left e          => Left e
      Right (as, ps') => parseSections k ps' ({ attestationSec := Just as } acc)
    Just TK_POLICY => case parsePolicySec ps of
      Left e          => Left e
      Right (pl, ps') => parseSections k ps' ({ policySec := Just pl } acc)
    _ => Right (acc, ps)  -- EOF or anything else: stop cleanly.

||| ENTRY POINT: Transforms a stream of tokens into a `Manifest`.
public export
parse : List Token -> Either ParseError Manifest
parse tokens =
  case parseSections (length tokens) (MkParserState tokens) emptyAccum of
    Left err => Left err
    Right (acc, _) =>
      case acc.manifestSec of
        Nothing => Left (MissingRequired "manifest")
        Just ms => Right (MkManifest ms acc.refsSec acc.attestationSec acc.policySec)
