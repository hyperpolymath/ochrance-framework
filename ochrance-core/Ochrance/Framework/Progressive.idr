-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Framework.Progressive
|||
||| Progressive strictness modes for the verification framework.
|||
||| The Ochrance framework supports three levels of verification strictness,
||| allowing subsystems to be verified at the appropriate level of assurance
||| for their deployment context:
|||
|||   Lax      — Structural checks only (development, quick checks)
|||   Checked  — Cryptographic hash verification (staging, CI)
|||   Attested — Full dependent-type proofs (production, safety-critical)
|||
||| Users can start with Lax mode and progressively increase strictness
||| as confidence grows, without changing the subsystem implementation.

module Ochrance.Framework.Progressive

%default total

--------------------------------------------------------------------------------
-- Verification modes
--------------------------------------------------------------------------------

||| The three levels of verification strictness.
|||
||| Each mode produces a different proof witness type (see Proof.idr):
|||   Lax      -> StructureValid
|||   Checked  -> HashesMatch
|||   Attested -> FullyAttested
public export
data VerificationMode = Lax | Checked | Attested

||| Decidable equality for verification modes.
public export
Eq VerificationMode where
  Lax      == Lax      = True
  Checked  == Checked  = True
  Attested == Attested = True
  _        == _        = False

||| Total ordering on verification modes (Lax < Checked < Attested).
public export
Ord VerificationMode where
  compare Lax      Lax      = EQ
  compare Lax      _        = LT
  compare Checked  Lax      = GT
  compare Checked  Checked  = EQ
  compare Checked  Attested = LT
  compare Attested Attested = EQ
  compare Attested _        = GT

||| Show instance for display/logging.
public export
Show VerificationMode where
  show Lax      = "Lax"
  show Checked  = "Checked"
  show Attested = "Attested"

--------------------------------------------------------------------------------
-- Strictness level as a natural number
--------------------------------------------------------------------------------

||| Map verification mode to a numeric strictness level.
||| Useful for comparison and threshold checking.
public export
strictnessLevel : VerificationMode -> Nat
strictnessLevel Lax      = 0
strictnessLevel Checked  = 1
strictnessLevel Attested = 2

||| Proof that Attested is strictly more strict than Checked.
public export
attestedStricterThanChecked : strictnessLevel Attested = 2
attestedStricterThanChecked = Refl

||| Proof that Checked is strictly more strict than Lax.
public export
checkedStricterThanLax : strictnessLevel Checked = 1
checkedStricterThanLax = Refl

--------------------------------------------------------------------------------
-- Mode predicates
--------------------------------------------------------------------------------

||| Is this mode at least as strict as the given threshold?
public export
atLeast : (threshold : VerificationMode) -> (mode : VerificationMode) -> Bool
atLeast threshold mode = strictnessLevel mode >= strictnessLevel threshold

||| Proof type: mode satisfies minimum strictness.
public export
data SatisfiesMinimum : (threshold : VerificationMode) -> (mode : VerificationMode) -> Type where
  ||| Witness that mode >= threshold.
  MeetsThreshold : {0 t, m : VerificationMode}
                -> (prf : atLeast t m = True)
                -> SatisfiesMinimum t m

||| Lax satisfies a Lax minimum.
public export
laxSatisfiesLax : SatisfiesMinimum Lax Lax
laxSatisfiesLax = MeetsThreshold Refl

||| Checked satisfies a Lax minimum.
public export
checkedSatisfiesLax : SatisfiesMinimum Lax Checked
checkedSatisfiesLax = MeetsThreshold Refl

||| Attested satisfies any minimum.
public export
attestedSatisfiesLax : SatisfiesMinimum Lax Attested
attestedSatisfiesLax = MeetsThreshold Refl

||| Attested satisfies a Checked minimum.
public export
attestedSatisfiesChecked : SatisfiesMinimum Checked Attested
attestedSatisfiesChecked = MeetsThreshold Refl

--------------------------------------------------------------------------------
-- Mode selection helpers
--------------------------------------------------------------------------------

||| Choose the stricter of two modes.
public export
stricter : VerificationMode -> VerificationMode -> VerificationMode
stricter m1 m2 = if strictnessLevel m1 >= strictnessLevel m2 then m1 else m2

||| Choose the more lenient of two modes.
public export
more_lenient : VerificationMode -> VerificationMode -> VerificationMode
more_lenient m1 m2 = if strictnessLevel m1 <= strictnessLevel m2 then m1 else m2
