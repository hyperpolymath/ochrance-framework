-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Parser — High-Assurance Manifest Parsing.
|||
||| This module implements a total, recursive-descent parser for the 
||| A2ML (Attested Markup Language) format. 
|||
||| TOTALITY GUARANTEE: The parser uses a "Fuel" parameter (indexed by the 
||| number of tokens) to prove termination to the Idris compiler. 
||| Every recursive call consumes one unit of fuel, ensuring the 
||| parser cannot enter an infinite loop.

module Ochrance.A2ML.Parser

import Ochrance.A2ML.Types
import Data.List

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

--------------------------------------------------------------------------------
-- Parsing Engine
--------------------------------------------------------------------------------

||| SECTION DISPATCH: Iteratively parses top-level A2ML directives.
||| Supported Sections: @manifest, @refs, @attestation, @policy.
parseSections : (fuel : Nat)
             -> ParserState
             -> SectionAccum
             -> Either ParseError (SectionAccum, ParserState)
parseSections Z     ps acc = Right (acc, ps)
parseSections (S k) ps acc =
  case peek ps of
    Just TK_MANIFEST =>
      -- 1. ADVANCE state.
      -- 2. PARSE section body.
      -- 3. UPDATE accumulator.
      parseSections k ps' ({ manifestSec := Just ms } acc)
    -- ... [Dispatch for other tags]
    _ => Right (acc, ps)

||| ENTRY POINT: Transforms a stream of tokens into a validated `Manifest`.
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
