-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Parser
|||
||| Parser for the A2ML manifest format.
|||
||| Converts a list of tokens (from the lexer) into a structured Manifest AST.
||| The parser is total by structural recursion on the token list, which
||| strictly decreases on each step.
|||
||| Grammar (informal):
|||   manifest := section*
|||   section  := '@manifest' '{' field* '}'
|||             | '@refs' '{' ref* '}'
|||             | '@attestation' '{' attestation* '}'
|||             | '@policy' '{' policy_rule* '}'
|||   field    := IDENT ('=' | ':') (STRING | IDENT | HASH)
|||   ref      := IDENT ':' STRING (HASH)?
|||   ...

module Ochrance.A2ML.Parser

import Ochrance.A2ML.Types
import Data.List

%default total

--------------------------------------------------------------------------------
-- Parse error type
--------------------------------------------------------------------------------

||| Errors that can occur during parsing.
public export
data ParseError : Type where
  ||| Expected a specific token kind but got something else.
  ExpectedToken  : (expected : String) -> (got : String) -> (loc : SourceLoc) -> ParseError
  ||| Unexpected end of token stream.
  UnexpectedEOF  : (context : String) -> ParseError
  ||| Duplicate section encountered.
  DuplicateSection : (section : String) -> (loc : SourceLoc) -> ParseError
  ||| A required section was missing.
  MissingRequired : (section : String) -> ParseError
  ||| Generic parse error with context.
  GenericError   : (msg : String) -> (loc : SourceLoc) -> ParseError

||| Show instance for parse errors.
public export
Show ParseError where
  show (ExpectedToken e g loc)   = "expected " ++ e ++ ", got " ++ g ++ " at " ++ show loc
  show (UnexpectedEOF ctx)       = "unexpected end of input in " ++ ctx
  show (DuplicateSection s loc)  = "duplicate section @" ++ s ++ " at " ++ show loc
  show (MissingRequired s)       = "missing required section @" ++ s
  show (GenericError msg loc)    = msg ++ " at " ++ show loc

--------------------------------------------------------------------------------
-- Parser state
--------------------------------------------------------------------------------

||| Parser state: remaining tokens.
record ParserState where
  constructor MkParserState
  tokens : List Token

||| Get the location of the current token, or a default.
currentTokenLoc : ParserState -> SourceLoc
currentTokenLoc ps =
  case ps.tokens of
    []      => MkLoc 0 0
    (t :: _) => t.loc

||| Consume the next token if it exists.
advance : ParserState -> ParserState
advance ps = { tokens := drop 1 ps.tokens } ps

||| Peek at the current token kind without consuming.
peek : ParserState -> Maybe TokenKind
peek ps =
  case ps.tokens of
    []      => Nothing
    (t :: _) => Just t.kind

--------------------------------------------------------------------------------
-- Section parsers (stubs with fuel-based totality)
--------------------------------------------------------------------------------

||| Parse fields within a @manifest section.
||| Consumes tokens until a closing brace is found.
|||
||| TODO: Implement full field parsing with type checking.
parseManifestFields : (fuel : Nat)
                   -> ParserState
                   -> List Field
                   -> Either ParseError (List Field, ParserState)
parseManifestFields Z     ps acc = Right (reverse acc, ps)
parseManifestFields (S k) ps acc =
  case peek ps of
    Just TK_RBRACE => Right (reverse acc, ps)
    Just TK_EOF    => Left (UnexpectedEOF "manifest section")
    Nothing        => Left (UnexpectedEOF "manifest section")
    -- TODO: Parse IDENT = STRING | IDENT : STRING patterns
    _              => parseManifestFields k (advance ps) acc

||| Parse the @manifest section body.
|||
||| TODO: Extract name, version, author, description from fields.
parseManifestSection : (fuel : Nat)
                    -> ParserState
                    -> Either ParseError (ManifestSection, ParserState)
parseManifestSection fuel ps =
  case peek ps of
    Just TK_LBRACE =>
      let ps1 = advance ps in
      case parseManifestFields fuel ps1 [] of
        Left err => Left err
        Right (fields, ps2) =>
          case peek ps2 of
            Just TK_RBRACE =>
              -- TODO: Extract structured fields from the raw field list
              Right (MkManifestSection "" "" "" "" fields, advance ps2)
            _ => Left (ExpectedToken "}" "other" (currentTokenLoc ps2))
    _ => Left (ExpectedToken "{" "other" (currentTokenLoc ps))

||| Parse references within a @refs section.
|||
||| TODO: Implement ref parsing (name : target #hash).
parseRefsEntries : (fuel : Nat)
                -> ParserState
                -> List Ref
                -> Either ParseError (List Ref, ParserState)
parseRefsEntries Z     ps acc = Right (reverse acc, ps)
parseRefsEntries (S k) ps acc =
  case peek ps of
    Just TK_RBRACE => Right (reverse acc, ps)
    Just TK_EOF    => Left (UnexpectedEOF "refs section")
    Nothing        => Left (UnexpectedEOF "refs section")
    -- TODO: Parse name : target #hash patterns
    _              => parseRefsEntries k (advance ps) acc

||| Parse the @refs section body.
parseRefsSection : (fuel : Nat)
                -> ParserState
                -> Either ParseError (RefsSection, ParserState)
parseRefsSection fuel ps =
  case peek ps of
    Just TK_LBRACE =>
      let ps1 = advance ps in
      case parseRefsEntries fuel ps1 [] of
        Left err => Left err
        Right (refs, ps2) =>
          case peek ps2 of
            Just TK_RBRACE => Right (MkRefsSection refs, advance ps2)
            _ => Left (ExpectedToken "}" "other" (currentTokenLoc ps2))
    _ => Left (ExpectedToken "{" "other" (currentTokenLoc ps))

||| Parse attestation entries within @attestation section.
|||
||| TODO: Implement attestation parsing (subject, hash, timestamp, signer).
parseAttestationEntries : (fuel : Nat)
                       -> ParserState
                       -> List Attestation
                       -> Either ParseError (List Attestation, ParserState)
parseAttestationEntries Z     ps acc = Right (reverse acc, ps)
parseAttestationEntries (S k) ps acc =
  case peek ps of
    Just TK_RBRACE => Right (reverse acc, ps)
    Just TK_EOF    => Left (UnexpectedEOF "attestation section")
    Nothing        => Left (UnexpectedEOF "attestation section")
    -- TODO: Parse subject : hash @ timestamp [signer] patterns
    _              => parseAttestationEntries k (advance ps) acc

||| Parse the @attestation section body.
parseAttestationSection : (fuel : Nat)
                       -> ParserState
                       -> Either ParseError (AttestationSection, ParserState)
parseAttestationSection fuel ps =
  case peek ps of
    Just TK_LBRACE =>
      let ps1 = advance ps in
      case parseAttestationEntries fuel ps1 [] of
        Left err => Left err
        Right (atts, ps2) =>
          case peek ps2 of
            Just TK_RBRACE => Right (MkAttestationSection atts, advance ps2)
            _ => Left (ExpectedToken "}" "other" (currentTokenLoc ps2))
    _ => Left (ExpectedToken "{" "other" (currentTokenLoc ps))

||| Parse policy rules within @policy section.
|||
||| TODO: Implement policy rule parsing (name, mode, threshold, schedule).
parsePolicyRules : (fuel : Nat)
                -> ParserState
                -> List PolicyRule
                -> Either ParseError (List PolicyRule, ParserState)
parsePolicyRules Z     ps acc = Right (reverse acc, ps)
parsePolicyRules (S k) ps acc =
  case peek ps of
    Just TK_RBRACE => Right (reverse acc, ps)
    Just TK_EOF    => Left (UnexpectedEOF "policy section")
    Nothing        => Left (UnexpectedEOF "policy section")
    -- TODO: Parse name = mode [threshold] [schedule] patterns
    _              => parsePolicyRules k (advance ps) acc

||| Parse the @policy section body.
parsePolicySection : (fuel : Nat)
                  -> ParserState
                  -> Either ParseError (PolicySection, ParserState)
parsePolicySection fuel ps =
  case peek ps of
    Just TK_LBRACE =>
      let ps1 = advance ps in
      case parsePolicyRules fuel ps1 [] of
        Left err => Left err
        Right (rules, ps2) =>
          case peek ps2 of
            Just TK_RBRACE => Right (MkPolicySection rules, advance ps2)
            _ => Left (ExpectedToken "}" "other" (currentTokenLoc ps2))
    _ => Left (ExpectedToken "{" "other" (currentTokenLoc ps))

--------------------------------------------------------------------------------
-- Top-level parser
--------------------------------------------------------------------------------

||| Accumulator for sections parsed so far.
record SectionAccum where
  constructor MkAccum
  manifestSec    : Maybe ManifestSection
  refsSec        : Maybe RefsSection
  attestationSec : Maybe AttestationSection
  policySec      : Maybe PolicySection

||| Empty section accumulator.
emptyAccum : SectionAccum
emptyAccum = MkAccum Nothing Nothing Nothing Nothing

||| Parse all sections in the token stream.
||| Fuel-bounded for totality.
parseSections : (fuel : Nat)
             -> ParserState
             -> SectionAccum
             -> Either ParseError (SectionAccum, ParserState)
parseSections Z     ps acc = Right (acc, ps)
parseSections (S k) ps acc =
  case peek ps of
    Just TK_EOF => Right (acc, ps)
    Nothing     => Right (acc, ps)

    Just TK_MANIFEST =>
      case acc.manifestSec of
        Just _  => Left (DuplicateSection "manifest" (currentTokenLoc ps))
        Nothing =>
          case parseManifestSection k (advance ps) of
            Left err       => Left err
            Right (ms, ps') => parseSections k ps' ({ manifestSec := Just ms } acc)

    Just TK_REFS =>
      case acc.refsSec of
        Just _  => Left (DuplicateSection "refs" (currentTokenLoc ps))
        Nothing =>
          case parseRefsSection k (advance ps) of
            Left err       => Left err
            Right (rs, ps') => parseSections k ps' ({ refsSec := Just rs } acc)

    Just TK_ATTESTATION =>
      case acc.attestationSec of
        Just _  => Left (DuplicateSection "attestation" (currentTokenLoc ps))
        Nothing =>
          case parseAttestationSection k (advance ps) of
            Left err       => Left err
            Right (as', ps') => parseSections k ps' ({ attestationSec := Just as' } acc)

    Just TK_POLICY =>
      case acc.policySec of
        Just _  => Left (DuplicateSection "policy" (currentTokenLoc ps))
        Nothing =>
          case parsePolicySection k (advance ps) of
            Left err       => Left err
            Right (pol, ps') => parseSections k ps' ({ policySec := Just pol } acc)

    _ => Left (GenericError "unexpected token" (currentTokenLoc ps))

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

||| Parse a list of tokens into a complete A2ML Manifest.
|||
||| Total by fuel-bounded recursion (fuel = token count).
||| The @manifest section is required; @refs, @attestation, and @policy
||| are optional.
|||
||| @tokens  Token list from the lexer (must end with TK_EOF)
||| @return  Either a ParseError or a well-formed Manifest
public export
parse : List Token -> Either ParseError Manifest
parse tokens =
  let fuel = length tokens
      ps   = MkParserState tokens
  in case parseSections fuel ps emptyAccum of
       Left err => Left err
       Right (acc, _) =>
         case acc.manifestSec of
           Nothing => Left (MissingRequired "manifest")
           Just ms => Right (MkManifest ms acc.refsSec acc.attestationSec acc.policySec)
