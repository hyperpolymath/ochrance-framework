-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Framework.Error — Structured Diagnostic System.
|||
||| This module implements the `q/p/z` diagnostic framework, ensuring that 
||| every verification failure carries sufficient context for automated 
||| remediation and audit.
|||
||| AXES:
||| - **q (Query)**: The technical root cause (e.g., Hash Mismatch).
||| - **p (Predicate)**: The operational priority (e.g., Critical, Warning).
||| - **z (Zone)**: The blast radius of the failure (e.g., Single Block, Subsystem).

module Ochrance.Framework.Error

%default total

--------------------------------------------------------------------------------
-- Diagnostic Axis (q)
--------------------------------------------------------------------------------

||| DIAGNOSTIC: Describes the physical or logical failure mode.
public export
data QueryDiagnostic : Type where
  MissingStructure   : (name : String) -> QueryDiagnostic
  HashMismatch       : (field : String) -> (expected : String) -> (actual : String) -> QueryDiagnostic
  InvariantViolation : (invariant : String) -> QueryDiagnostic
  ParseFailure       : (context : String) -> (line, col : Nat) -> QueryDiagnostic

--------------------------------------------------------------------------------
-- Priority Axis (p)
--------------------------------------------------------------------------------

||| PRIORITY: Reflects the severity and urgency of the diagnostic.
public export
data Priority : Type where
  Info     : Priority -- Advisory only.
  Warning  : Priority -- Non-blocking issue.
  Error    : Priority -- Formal compliance failure.
  Critical : Priority -- System integrity compromised.

--------------------------------------------------------------------------------
-- Impact Axis (z)
--------------------------------------------------------------------------------

||| IMPACT ZONE: Identifies the scope of the affected system components.
public export
data ImpactZone : Type where
  SingleBlock   : (path : String) -> ImpactZone
  FullSubsystem : (name : String) -> ImpactZone
  CrossCutting  : (subsystems : List String) -> ImpactZone

--------------------------------------------------------------------------------
-- Composite Error
--------------------------------------------------------------------------------

||| OCHRANCE ERROR: The unified diagnostic record.
public export
record OchranceError where
  constructor MkError
  query    : QueryDiagnostic
  priority : Priority
  zone     : ImpactZone

||| SERIALIZATION: Produces a standardized error string: "[PRIORITY] q | z".
public export
showError : OchranceError -> String
showError err = "[" ++ showPriority err.priority ++ "] "
             ++ showQuery err.query ++ " | "
             ++ showZone err.zone
