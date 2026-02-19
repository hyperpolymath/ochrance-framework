-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Framework.Error
|||
||| The q/p/z error diagnostic system for Ochrance.
|||
||| Every error in the framework is described by three components:
|||
|||   q = Query/Diagnostic  — WHAT happened
|||   p = Predicate/Priority — WHY it matters (severity)
|||   z = Zone/Impact       — WHAT is affected (blast radius)
|||
||| This structured approach ensures that every error carries enough
||| context for automated triage, human diagnosis, and repair planning.

module Ochrance.Framework.Error

%default total

--------------------------------------------------------------------------------
-- q: Query/Diagnostic — what happened
--------------------------------------------------------------------------------

||| The diagnostic component: what went wrong.
||| Each variant describes a specific failure mode.
public export
data QueryDiagnostic : Type where
  ||| A required structure was missing from the state.
  MissingStructure   : (name : String) -> QueryDiagnostic
  ||| A cryptographic hash did not match the expected value.
  HashMismatch       : (field : String) -> (expected : String) -> (actual : String) -> QueryDiagnostic
  ||| A required section was absent from the manifest.
  MissingSection     : (section : String) -> QueryDiagnostic
  ||| A version incompatibility was detected.
  VersionMismatch    : (expected : String) -> (actual : String) -> QueryDiagnostic
  ||| An invariant that should always hold was violated.
  InvariantViolation : (invariant : String) -> QueryDiagnostic
  ||| A parse error occurred while reading a manifest or config.
  ParseFailure       : (context : String) -> (line : Nat) -> (col : Nat) -> QueryDiagnostic
  ||| An I/O operation failed during repair or attestation.
  IOFailure          : (operation : String) -> (reason : String) -> QueryDiagnostic
  ||| A snapshot was corrupt or incompatible.
  SnapshotCorrupt    : (snapshotId : String) -> QueryDiagnostic

--------------------------------------------------------------------------------
-- p: Predicate/Priority — why it matters
--------------------------------------------------------------------------------

||| The severity/priority component: how urgent is this?
public export
data Priority : Type where
  ||| Informational only — no action required.
  Info     : Priority
  ||| Something is suboptimal but not broken.
  Warning  : Priority
  ||| A verification failure that needs attention.
  Error    : Priority
  ||| System integrity is compromised; immediate action required.
  Critical : Priority

||| Numeric severity for sorting/filtering.
public export
priorityLevel : Priority -> Nat
priorityLevel Info     = 0
priorityLevel Warning  = 1
priorityLevel Error    = 2
priorityLevel Critical = 3

||| Priority ordering.
public export
Eq Priority where
  Info     == Info     = True
  Warning  == Warning  = True
  Error    == Error    = True
  Critical == Critical = True
  _        == _        = False

public export
Ord Priority where
  compare p1 p2 = compare (priorityLevel p1) (priorityLevel p2)

--------------------------------------------------------------------------------
-- z: Zone/Impact — what is affected
--------------------------------------------------------------------------------

||| The impact zone: what part of the system is affected.
public export
data ImpactZone : Type where
  ||| A single file or block is affected.
  SingleBlock  : (path : String) -> ImpactZone
  ||| A subtree of the filesystem/structure is affected.
  Subtree      : (root : String) -> (depth : Nat) -> ImpactZone
  ||| The entire subsystem is affected.
  FullSubsystem : (name : String) -> ImpactZone
  ||| Multiple subsystems are affected (cross-cutting).
  CrossCutting : (subsystems : List String) -> ImpactZone

--------------------------------------------------------------------------------
-- OchranceError: the composite error type
--------------------------------------------------------------------------------

||| A complete Ochrance error combining all three diagnostic axes.
|||
||| Every error in the system carries:
|||   - q: what happened (diagnostic)
|||   - p: why it matters (priority)
|||   - z: what is affected (impact zone)
public export
record OchranceError where
  constructor MkError
  ||| q — what happened
  query    : QueryDiagnostic
  ||| p — why it matters
  priority : Priority
  ||| z — what is affected
  zone     : ImpactZone

--------------------------------------------------------------------------------
-- Error constructors for common cases
--------------------------------------------------------------------------------

||| Create a hash mismatch error for a specific field.
public export
hashError : (field : String) -> (expected : String) -> (actual : String) -> (zone : ImpactZone) -> OchranceError
hashError field expected actual zone =
  MkError (HashMismatch field expected actual) Error zone

||| Create a critical missing-structure error.
public export
missingError : (name : String) -> (zone : ImpactZone) -> OchranceError
missingError name zone =
  MkError (MissingStructure name) Critical zone

||| Create a parse failure error with location information.
public export
parseError : (context : String) -> (line : Nat) -> (col : Nat) -> OchranceError
parseError ctx line col =
  MkError (ParseFailure ctx line col) Error (FullSubsystem "parser")

||| Create an informational version mismatch.
public export
versionWarning : (expected : String) -> (actual : String) -> (subsystem : String) -> OchranceError
versionWarning expected actual sub =
  MkError (VersionMismatch expected actual) Warning (FullSubsystem sub)

--------------------------------------------------------------------------------
-- Error display
--------------------------------------------------------------------------------

||| Render a QueryDiagnostic as a human-readable string.
public export
showQuery : QueryDiagnostic -> String
showQuery (MissingStructure name) = "missing structure: " ++ name
showQuery (HashMismatch f e a)    = "hash mismatch on " ++ f ++ ": expected " ++ e ++ ", got " ++ a
showQuery (MissingSection s)      = "missing section: " ++ s
showQuery (VersionMismatch e a)   = "version mismatch: expected " ++ e ++ ", got " ++ a
showQuery (InvariantViolation i)  = "invariant violated: " ++ i
showQuery (ParseFailure c l col)  = "parse error in " ++ c ++ " at " ++ show l ++ ":" ++ show col
showQuery (IOFailure op r)        = "I/O failure in " ++ op ++ ": " ++ r
showQuery (SnapshotCorrupt sid)   = "corrupt snapshot: " ++ sid

||| Render a Priority as a string tag.
public export
showPriority : Priority -> String
showPriority Info     = "INFO"
showPriority Warning  = "WARN"
showPriority Error    = "ERROR"
showPriority Critical = "CRITICAL"

||| Render an ImpactZone as a human-readable string.
public export
showZone : ImpactZone -> String
showZone (SingleBlock path)      = "block:" ++ path
showZone (Subtree root depth)    = "subtree:" ++ root ++ " (depth " ++ show depth ++ ")"
showZone (FullSubsystem name)    = "subsystem:" ++ name
showZone (CrossCutting subs)     = "cross-cutting:" ++ show subs

||| Render a full OchranceError as "[PRIORITY] q | z".
public export
showError : OchranceError -> String
showError err = "[" ++ showPriority err.priority ++ "] "
             ++ showQuery err.query ++ " | "
             ++ showZone err.zone
