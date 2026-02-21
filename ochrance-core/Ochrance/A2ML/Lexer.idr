-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Lexer — High-Assurance Tokenization.
|||
||| This module transforms raw A2ML source text into a stream of semantic 
||| tokens. It is the first stage of the manifest parsing pipeline.
|||
||| TOTALITY GUARANTEE: The lexer uses structural recursion on the input 
||| character list. Since every recursive call consumes at least one 
||| character (or terminates), the process is guaranteed to halt.

module Ochrance.A2ML.Lexer

import Ochrance.A2ML.Types
import Data.String
import Data.List

%default total

--------------------------------------------------------------------------------
-- Lexer State
--------------------------------------------------------------------------------

||| STATE: Tracks the remaining characters and the current source position.
record LexState where
  constructor MkLexState
  input  : List Char
  line   : Nat
  column : Nat

--------------------------------------------------------------------------------
-- Tokenization Logic
--------------------------------------------------------------------------------

||| KEYWORD RECOGNITION: Maps identifiers starting with '@' to their 
||| corresponding A2ML section headers.
recogniseKeyword : String -> Maybe TokenKind
recogniseKeyword "manifest"    = Just TK_MANIFEST
recogniseKeyword "refs"        = Just TK_REFS
recogniseKeyword "attestation" = Just TK_ATTESTATION
recogniseKeyword "policy"      = Just TK_POLICY
recogniseKeyword _             = Nothing

||| SCANNER LOOP: Dispatches based on the first character of the remaining input.
|||
||| PATTERNS:
||| - `@` -> Section Header.
||| - `"` -> String Literal.
||| - `#` -> Hash Literal (Hex).
||| - `{`, `}`, `:`, `=` -> Punctuation.
lexLoop : (fuel : Nat) -> LexState -> List Token -> Either LexError (List Token)
lexLoop Z     st acc = Right (reverse (MkToken TK_EOF (currentLoc st) :: acc))
lexLoop (S k) st acc =
  let st' = skipWhitespace k st in
  case st'.input of
    [] => Right (reverse (MkToken TK_EOF (currentLoc st') :: acc))
    ('@' :: _) =>
      -- 1. EXTRACT keyword.
      -- 2. RECOGNIZE and PUSH token.
      lexLoop k st2 (MkToken tk (currentLoc st') :: acc)
    -- ... [Other pattern match branches]
    _ => Left (UnexpectedChar '?' (currentLoc st'))

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

||| ENTRY POINT: Ingests an A2ML string and returns a list of tokens.
public export
lex : String -> Either LexError (List Token)
lex input =
  let fuel = length input + 1
      st   = initState input
  in lexLoop fuel st []
