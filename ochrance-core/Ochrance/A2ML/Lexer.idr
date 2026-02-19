-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.A2ML.Lexer
|||
||| Lexer for the A2ML manifest format.
|||
||| Converts raw input text into a list of typed tokens with source
||| location tracking. The lexer is total by structural recursion on
||| the input character list (which strictly decreases on each step).
|||
||| Token types:
|||   MANIFEST, REFS, ATTESTATION, POLICY — section headers (@keyword)
|||   LBRACE, RBRACE, COLON, EQUALS       — punctuation
|||   IDENT, STRING, HASH                  — values
|||   EOF                                  — end of input
|||
||| Error tracking includes line and column for precise diagnostics.

module Ochrance.A2ML.Lexer

import Ochrance.A2ML.Types
import Data.String
import Data.List

%default total

--------------------------------------------------------------------------------
-- Lexer error type
--------------------------------------------------------------------------------

||| Errors that can occur during lexing.
public export
data LexError : Type where
  ||| An unexpected character was encountered.
  UnexpectedChar : (ch : Char) -> (loc : SourceLoc) -> LexError
  ||| A string literal was not properly terminated.
  UnterminatedString : (loc : SourceLoc) -> LexError
  ||| A hash literal was malformed (not valid hex).
  MalformedHash : (loc : SourceLoc) -> LexError
  ||| An unknown section keyword was encountered.
  UnknownKeyword : (kw : String) -> (loc : SourceLoc) -> LexError

||| Show instance for lexer errors.
public export
Show LexError where
  show (UnexpectedChar ch loc)    = "unexpected character '" ++ singleton ch ++ "' at " ++ show loc
  show (UnterminatedString loc)   = "unterminated string at " ++ show loc
  show (MalformedHash loc)        = "malformed hash at " ++ show loc
  show (UnknownKeyword kw loc)    = "unknown keyword '@" ++ kw ++ "' at " ++ show loc

--------------------------------------------------------------------------------
-- Character classification helpers
--------------------------------------------------------------------------------

||| Is this character a valid identifier start? (letter or underscore)
isIdentStart : Char -> Bool
isIdentStart c = isAlpha c || c == '_'

||| Is this character a valid identifier continuation?
isIdentCont : Char -> Bool
isIdentCont c = isAlphaNum c || c == '_' || c == '-' || c == '.'

||| Is this character a valid hexadecimal digit?
isHexChar : Char -> Bool
isHexChar c = isDigit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

||| Is this character whitespace?
isSpace : Char -> Bool
isSpace ' '  = True
isSpace '\t' = True
isSpace '\n' = True
isSpace '\r' = True
isSpace _    = False

--------------------------------------------------------------------------------
-- Keyword recognition
--------------------------------------------------------------------------------

||| Attempt to recognise a keyword string as a section header token kind.
||| Returns Nothing for unrecognised keywords.
recogniseKeyword : String -> Maybe TokenKind
recogniseKeyword "manifest"    = Just TK_MANIFEST
recogniseKeyword "refs"        = Just TK_REFS
recogniseKeyword "attestation" = Just TK_ATTESTATION
recogniseKeyword "policy"      = Just TK_POLICY
recogniseKeyword _             = Nothing

--------------------------------------------------------------------------------
-- Lexer state
--------------------------------------------------------------------------------

||| Internal lexer state tracking position in input.
record LexState where
  constructor MkLexState
  input  : List Char
  line   : Nat
  column : Nat

||| Create initial lexer state from input string.
initState : String -> LexState
initState s = MkLexState (unpack s) 1 1

||| Advance the position by one character, tracking newlines.
advancePos : Char -> LexState -> LexState
advancePos '\n' st = { input := drop 1 st.input, line := st.line + 1, column := 1 } st
advancePos _    st = { input := drop 1 st.input, column := st.column + 1 } st

||| Get current source location from lexer state.
currentLoc : LexState -> SourceLoc
currentLoc st = MkLoc st.line st.column

--------------------------------------------------------------------------------
-- Core lexer (total by structural recursion on fuel)
--------------------------------------------------------------------------------

||| Lex a string literal, collecting characters until closing quote.
||| Uses fuel (Nat) to ensure totality via structural recursion.
lexString : (fuel : Nat) -> LexState -> Either LexError (String, LexState)
lexString Z     st = Left (UnterminatedString (currentLoc st))
lexString (S k) st =
  case st.input of
    []          => Left (UnterminatedString (currentLoc st))
    ('"' :: _)  => Right ("", advancePos '"' st)
    ('\\' :: c :: rest) =>
      case lexString k (advancePos c (advancePos '\\' st)) of
        Left err         => Left err
        Right (s, st')   => Right (singleton c ++ s, st')
    (c :: _) =>
      case lexString k (advancePos c st) of
        Left err         => Left err
        Right (s, st')   => Right (singleton c ++ s, st')

||| Lex an identifier, collecting alphanumeric/underscore/dash/dot characters.
lexIdent : LexState -> (String, LexState)
lexIdent st =
  let chars = takeWhile isIdentCont st.input
      len   = length chars
      rest  = drop len st.input
      newSt = { input := rest, column := st.column + len } st
  in (pack chars, newSt)

||| Lex a hash literal (hex digits after '#').
lexHash : LexState -> Either LexError (String, LexState)
lexHash st =
  let chars = takeWhile isHexChar st.input
      len   = length chars
      rest  = drop len st.input
      newSt = { input := rest, column := st.column + len } st
  in if len == 0
     then Left (MalformedHash (currentLoc st))
     else Right (pack chars, newSt)

||| Skip whitespace and comments, advancing the lexer state.
skipWhitespace : (fuel : Nat) -> LexState -> LexState
skipWhitespace Z     st = st
skipWhitespace (S k) st =
  case st.input of
    []       => st
    (c :: _) =>
      if isSpace c
      then skipWhitespace k (advancePos c st)
      else st

||| Main lexer loop. Uses fuel for totality guarantee.
|||
||| @fuel  Recursion bound (should be >= input length)
||| @st    Current lexer state
||| @acc   Accumulated tokens (in reverse)
lexLoop : (fuel : Nat) -> LexState -> List Token -> Either LexError (List Token)
lexLoop Z     st acc = Right (reverse (MkToken TK_EOF (currentLoc st) :: acc))
lexLoop (S k) st acc =
  let st' = skipWhitespace k st in
  case st'.input of
    -- End of input
    [] => Right (reverse (MkToken TK_EOF (currentLoc st') :: acc))

    -- Section keyword (@...)
    ('@' :: _) =>
      let st1 = advancePos '@' st'
          (kw, st2) = lexIdent st1
      in case recogniseKeyword kw of
           Just tk => lexLoop k st2 (MkToken tk (currentLoc st') :: acc)
           Nothing => Left (UnknownKeyword kw (currentLoc st'))

    -- Punctuation
    ('{' :: _) => lexLoop k (advancePos '{' st') (MkToken TK_LBRACE (currentLoc st') :: acc)
    ('}' :: _) => lexLoop k (advancePos '}' st') (MkToken TK_RBRACE (currentLoc st') :: acc)
    (':' :: _) => lexLoop k (advancePos ':' st') (MkToken TK_COLON  (currentLoc st') :: acc)
    ('=' :: _) => lexLoop k (advancePos '=' st') (MkToken TK_EQUALS (currentLoc st') :: acc)

    -- String literal
    ('"' :: _) =>
      case lexString k (advancePos '"' st') of
        Left err       => Left err
        Right (s, st2) => lexLoop k st2 (MkToken (TK_STRING s) (currentLoc st') :: acc)

    -- Hash literal
    ('#' :: _) =>
      case lexHash (advancePos '#' st') of
        Left err       => Left err
        Right (h, st2) => lexLoop k st2 (MkToken (TK_HASH h) (currentLoc st') :: acc)

    -- Identifier
    (c :: _) =>
      if isIdentStart c
      then let (ident, st2) = lexIdent st'
           in lexLoop k st2 (MkToken (TK_IDENT ident) (currentLoc st') :: acc)
      else Left (UnexpectedChar c (currentLoc st'))

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

||| Lex an A2ML input string into a list of tokens.
|||
||| Total by structural recursion on fuel, which is set to the input
||| length plus a safety margin. The fuel strictly decreases on each
||| recursive call because we always consume at least one character
||| or terminate.
|||
||| @input  The raw A2ML source text
||| @return Either a LexError with location, or a list of tokens ending in EOF
public export
lex : String -> Either LexError (List Token)
lex input =
  let fuel = length input + 1  -- +1 for the EOF token
      st   = initState input
  in lexLoop fuel st []
