-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Framework.Proof — Formal Verification Witnesses.
|||
||| This module defines the core evidence types produced by the Ochrance 
||| verification engine. It implements a "Progressive Assurance" model 
||| where proofs can be strengthened as more evidence is gathered.
|||
//! LEVELS OF ASSURANCE:
//! 1. **StructureValid**: Lax mode. Checks that fields exist and have correct types.
//! 2. **HashesMatch**: Checked mode. Proves cryptographic equality (computed == expected).
//! 3. **FullyAttested**: Attested mode. Verifies all domain-specific invariants.

module Ochrance.Framework.Proof

import Ochrance.Framework.Progressive

%default total

--------------------------------------------------------------------------------
-- Integrity Models
--------------------------------------------------------------------------------

||| WITNESS: Lax Verification.
||| Confirms that the physical shape of the data matches the manifest.
public export
data StructureValid : (state : Type) -> (manifest : Type) -> Type where
  MkStructureValid : {0 s : Type} -> {0 m : Type}
                  -> (fieldCount : Nat)
                  -> (allPresent : Bool)
                  -> StructureValid s m

||| WITNESS: Checked Verification.
||| Confirms that the data content is authentic.
public export
data HashesMatch : (state : Type) -> (manifest : Type) -> Type where
  MkHashesMatch : {0 s : Type} -> {0 m : Type}
               -> (structureOk : StructureValid s m)
               -> (computed : HashValue)
               -> (expected : HashValue)
               -> (hashProof : computed = expected) // FORMAL EQUALITY PROOF
               -> HashesMatch s m

--------------------------------------------------------------------------------
-- Proof Orchestration
--------------------------------------------------------------------------------

||| DISPATCH: Maps a runtime `VerificationMode` to its required proof witness.
||| This allows generic verification logic to be parameterized by the 
||| desired level of strictness.
public export
VerificationProof : VerificationMode -> Type -> Type -> Type
VerificationProof Lax      s m = StructureValid s m
VerificationProof Checked  s m = HashesMatch s m
VerificationProof Attested s m = FullyAttested s m

||| STRENGTHENING: Promotes a structural proof to a hash-verified proof 
||| by providing evidence of cryptographic equality.
public export
strengthen : StructureValid s m
          -> (computed : HashValue)
          -> (expected : HashValue)
          -> (prf : computed = expected)
          -> HashesMatch s m
strengthen sv c e prf = MkHashesMatch sv c e prf
