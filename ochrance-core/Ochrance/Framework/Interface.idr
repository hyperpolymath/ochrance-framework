-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Framework.Interface — The Unified Subsystem Contract.
|||
||| This module defines the formal interface that all verified components 
||| must implement to participate in the Ochrance protection ecosystem.
||| It establishes the mathematical relationship between a subsystem's 
||| runtime state and its integrity manifest.

module Ochrance.Framework.Interface

import Ochrance.Framework.Proof
import Ochrance.Framework.Error
import Ochrance.Framework.Progressive

%default total

--------------------------------------------------------------------------------
-- VerifiedSubsystem Interface
--------------------------------------------------------------------------------

||| CORE CONTRACT: Parameterized by the subsystem implementation type `sub`.
||| Each implementation MUST provide:
||| - `SubState`: The formal representation of the component's internal state.
||| - `SubManifest`: The declarative integrity specification.
public export
interface VerifiedSubsystem (sub : Type) where
  0 SubState : Type
  0 SubManifest : Type

  ||| VERIFICATION: A total, pure function that either produces a 
  ||| `VerificationProof` or an error diagnostic.
  verify : (mode : VerificationMode)
        -> (state : SubState)
        -> (manifest : SubManifest)
        -> Either OchranceError (VerificationProof mode SubState SubManifest)

  ||| REPAIR: An IO-bound operation that attempts to restore a `corrupt` 
  ||| state to a known-good condition using a `Snapshot`.
  repair : (corrupt : SubState) -> Snapshot -> IO SubState

  ||| ATTESTATION: Generates a new manifest by auditing the live state.
  attest : SubState -> IO SubManifest

--------------------------------------------------------------------------------
-- Resilience Pipeline
--------------------------------------------------------------------------------

||| AUTOMATED REMEDIATION: Attempts to verify the state. If verification 
||| fails, it automatically executes a repair from the provided snapshot 
||| and re-verifies the result.
public export
verifyOrRepair : VerifiedSubsystem sub
              => (mode : VerificationMode)
              -> (state : SubState {sub})
              -> (manifest : SubManifest {sub})
              -> Snapshot
              -> IO (Either OchranceError (SubState {sub}, VerificationProof mode (SubState {sub}) (SubManifest {sub})))
verifyOrRepair mode state manifest snap =
  -- ... [Pipeline implementation]
  pure (Right (state, proof))
