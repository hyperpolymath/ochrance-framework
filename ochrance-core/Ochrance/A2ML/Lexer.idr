-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

||| Ochrance.A2ML.Lexer — High-Assurance Tokenization.
|||
||| This module transforms raw A2ML source text into a stream of semantic
||| tokens. It is the first stage of the manifest parsing pipeline.
|||
||| TOTALITY GUARANTEE: the scanner is fuel-bounded (fuel initialised to the
||| input length); every iteration either consumes input and decrements fuel,
||| or terminates. The character collectors recurse structurally on the input.

module Ochrance.A2ML.Lexer

import Ochrance.A2ML.Types
import Data.String
import Data.List

%default total

--------------------------------------------------------------------------------
-- Errors and State
--------------------------------------------------------------------------------

||| LEX ERROR: a character that cannot begin any token, or an unterminated string.
public export
data LexError : Type where
  UnexpectedChar     : (char : Char) -> (loc : SourceLoc) -> LexError
  UnterminatedString : (loc : SourceLoc) -> LexError

||| STATE: the remaining characters and the current source position.
record LexState where
  constructor MkLexState
  input  : List Char
  line   : Nat
  column : Nat

currentLoc : LexState -> SourceLoc
currentLoc st = MkSourceLoc st.line st.column

initState : String -> LexState
initState s = MkLexState (unpack s) 1 1

--------------------------------------------------------------------------------
-- Character classes and collectors
--------------------------------------------------------------------------------

isIdentStartChar : Char -> Bool
isIdentStartChar c = isAlpha c || c == '_'

isIdentChar : Char -> Bool
isIdentChar c = isAlphaNum c || c == '_' || c == '-' || c == '.'

||| Collect the longest prefix satisfying `p` (structural recursion).
collectWhile : (Char -> Bool) -> List Char -> (List Char, List Char)
collectWhile p [] = ([], [])
collectWhile p (c :: cs) =
  if p c then let (a, b) = collectWhile p cs in (c :: a, b)
         else ([], c :: cs)

||| Collect a string body up to (and consuming) the closing quote.
collectString : List Char -> Maybe (List Char, List Char)
collectString []          = Nothing
collectString ('"' :: cs) = Just ([], cs)
collectString (c   :: cs) = map (\(a, b) => (c :: a, b)) (collectString cs)

||| KEYWORD RECOGNITION: maps an `@`-prefixed word to its section header token.
recogniseKeyword : String -> Maybe TokenKind
recogniseKeyword "manifest"    = Just TK_MANIFEST
recogniseKeyword "refs"        = Just TK_REFS
recogniseKeyword "attestation" = Just TK_ATTESTATION
recogniseKeyword "policy"      = Just TK_POLICY
recogniseKeyword _             = Nothing

||| Bare words `true`/`false` lex as booleans; anything else is an identifier.
identOrBool : String -> TokenKind
identOrBool "true"  = TK_BOOL True
identOrBool "false" = TK_BOOL False
identOrBool s       = TK_IDENT s

digitsToNat : List Char -> Nat
digitsToNat ds = integerToNat (cast (pack ds))

--------------------------------------------------------------------------------
-- Scanner
--------------------------------------------------------------------------------

||| SCANNER LOOP: dispatches on the first character of the remaining input.
lexLoop : (fuel : Nat) -> LexState -> List Token -> Either LexError (List Token)
lexLoop Z     st acc = Right (reverse (MkToken TK_EOF (currentLoc st) :: acc))
lexLoop (S k) st acc =
  case st.input of
    [] => Right (reverse (MkToken TK_EOF (currentLoc st) :: acc))
    (c :: cs) =>
      let loc = currentLoc st in
      if c == '\n'
        then lexLoop k (MkLexState cs (S st.line) 1) acc
      else if c == ' ' || c == '\t' || c == '\r'
        then lexLoop k (MkLexState cs st.line (S st.column)) acc
      else if c == '{'
        then lexLoop k (MkLexState cs st.line (S st.column)) (MkToken TK_LBRACE loc :: acc)
      else if c == '}'
        then lexLoop k (MkLexState cs st.line (S st.column)) (MkToken TK_RBRACE loc :: acc)
      else if c == ':'
        then lexLoop k (MkLexState cs st.line (S st.column)) (MkToken TK_COLON loc :: acc)
      else if c == '='
        then lexLoop k (MkLexState cs st.line (S st.column)) (MkToken TK_EQUALS loc :: acc)
      else if c == '"'
        then case collectString cs of
               Nothing => Left (UnterminatedString loc)
               Just (strChars, rest) =>
                 let col' = st.column + length strChars + 2 in
                 lexLoop k (MkLexState rest st.line col') (MkToken (TK_STRING (pack strChars)) loc :: acc)
      else if c == '@'
        then let (word, rest) = collectWhile isIdentChar cs in
             case recogniseKeyword (pack word) of
               Just tk => lexLoop k (MkLexState rest st.line (st.column + 1 + length word)) (MkToken tk loc :: acc)
               Nothing => Left (UnexpectedChar '@' loc)
      else if isDigit c
        then let (digits, rest) = collectWhile isDigit (c :: cs) in
             lexLoop k (MkLexState rest st.line (st.column + length digits))
                       (MkToken (TK_NUMBER (digitsToNat digits)) loc :: acc)
      else if isIdentStartChar c
        then let (word, rest) = collectWhile isIdentChar (c :: cs)
                 wordStr      = pack word
             in case rest of
                  (':' :: afterColon) =>
                    let (hashChars, rest') = collectWhile isHexDigit afterColon in
                    if length hashChars > 0
                      then let raw  = wordStr ++ ":" ++ pack hashChars
                               col' = st.column + length word + 1 + length hashChars
                           in lexLoop k (MkLexState rest' st.line col') (MkToken (TK_HASH raw) loc :: acc)
                      else lexLoop k (MkLexState rest st.line (st.column + length word))
                                    (MkToken (identOrBool wordStr) loc :: acc)
                  _ => lexLoop k (MkLexState rest st.line (st.column + length word))
                                (MkToken (identOrBool wordStr) loc :: acc)
      else Left (UnexpectedChar c loc)

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

||| ENTRY POINT: Ingests an A2ML string and returns a list of tokens.
public export
lex : String -> Either LexError (List Token)
lex input = lexLoop (length (unpack input) + 1) (initState input) []
