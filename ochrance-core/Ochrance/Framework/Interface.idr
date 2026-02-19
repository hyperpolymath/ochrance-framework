-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Framework.Interface
|||
||| The core VerifiedSubsystem interface that all verified subsystems must
||| implement. This defines the contract for verification, repair, and
||| attestation of any subsystem managed by the Ochrance framework.
|||
||| A VerifiedSubsystem is parameterised by:
|||   - Its own type (sub)
|||   - An associated State type (the subsystem's runtime state)
|||   - An associated Manifest type (the subsystem's integrity manifest)
|||
||| The three fundamental operations are:
|||   verify  - Pure verification producing a proof witness
|||   repair  - IO-bound repair from a known-good snapshot
|||   attest  - IO-bound manifest generation from current state

module Ochrance.Framework.Interface

import Ochrance.Framework.Proof
import Ochrance.Framework.Error
import Ochrance.Framework.Progressive

%default total

--------------------------------------------------------------------------------
-- Snapshot type
--------------------------------------------------------------------------------

||| A snapshot captures a known-good state for repair purposes.
||| The content is opaque to the framework; each subsystem defines its own
||| snapshot format internally.
public export
record Snapshot where
  constructor MkSnapshot
  ||| Unique identifier for this snapshot
  snapshotId : String
  ||| Timestamp of snapshot creation (Unix epoch seconds)
  timestamp  : Bits64
  ||| Opaque payload — subsystem-specific serialised state
  payload    : List Bits8

--------------------------------------------------------------------------------
-- VerifiedSubsystem interface
--------------------------------------------------------------------------------

||| The main interface that all verified subsystems implement.
|||
||| Each subsystem carries:
|||   - A State type representing its runtime condition
|||   - A Manifest type representing its integrity declaration
|||   - Pure verification (no IO, deterministic)
|||   - IO-bound repair and attestation
public export
interface VerifiedSubsystem (sub : Type) where

  ||| The runtime state of the subsystem.
  ||| For a filesystem this might include block maps and metadata;
  ||| for a network subsystem, routing tables and connection state.
  0 SubState : Type

  ||| The integrity manifest describing expected state.
  ||| Contains hashes, version info, and any constraints
  ||| that the state must satisfy.
  0 SubManifest : Type

  ||| Pure verification: given a state and manifest, either produce a
  ||| proof witness (at the specified strictness level) or an error
  ||| diagnostic explaining what failed.
  |||
  ||| This function MUST be total and pure — no IO, no partiality.
  ||| The proof witness type depends on the verification mode:
  |||   Lax      -> StructureValid
  |||   Checked  -> HashesMatch
  |||   Attested -> FullyAttested
  verify : (mode : VerificationMode)
        -> (state : SubState)
        -> (manifest : SubManifest)
        -> Either OchranceError (VerificationProof mode SubState SubManifest)

  ||| Repair a corrupt state from a known-good snapshot.
  ||| This is necessarily IO-bound because it may read from disk,
  ||| network, or other external sources.
  |||
  ||| The returned state should pass verification at Checked level
  ||| or higher.
  repair : (corrupt : SubState) -> Snapshot -> IO SubState

  ||| Generate a manifest attesting to the current state.
  ||| Reads the live state and produces a manifest that can be
  ||| stored and later used for verification.
  attest : SubState -> IO SubManifest

--------------------------------------------------------------------------------
-- Convenience: verify-then-repair pipeline
--------------------------------------------------------------------------------

||| Attempt verification; if it fails, repair from snapshot and re-verify.
||| Returns the (possibly repaired) state and its proof.
public export
verifyOrRepair : VerifiedSubsystem sub
              => (mode : VerificationMode)
              -> (state : SubState {sub})
              -> (manifest : SubManifest {sub})
              -> Snapshot
              -> IO (Either OchranceError (SubState {sub}, VerificationProof mode (SubState {sub}) (SubManifest {sub})))
verifyOrRepair mode state manifest snap =
  case verify {sub} mode state manifest of
    Right proof => pure (Right (state, proof))
    Left _ => do
      repaired <- repair {sub} state snap
      case verify {sub} mode repaired manifest of
        Right proof => pure (Right (repaired, proof))
        Left err    => pure (Left err)
