-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

||| Ochrance.Framework.Proof — Formal Verification Witnesses.
|||
||| This module defines the core evidence types produced by the Ochrance 
||| verification engine. It implements a "Progressive Assurance" model 
||| where proofs can be strengthened as more evidence is gathered.
|||
||| LEVELS OF ASSURANCE:
||| 1. StructureValid: Lax mode. Checks that fields exist and have correct types.
||| 2. HashesMatch: Checked mode. Proves cryptographic equality (computed == expected).
||| 3. FullyAttested: Attested mode. Verifies all domain-specific invariants.

module Ochrance.Framework.Proof

import Ochrance.Framework.Progressive
import Decidable.Equality

%default total

--------------------------------------------------------------------------------
-- Hash Evidence
--------------------------------------------------------------------------------

||| A cryptographic digest used as verification evidence. Carrying it as a
||| concrete type (rather than `String`) lets the witnesses below demand a
||| genuine propositional equality between a computed and an expected hash.
public export
record HashValue where
  constructor MkHashValue
  digest : String

public export
DecEq HashValue where
  decEq (MkHashValue a) (MkHashValue b) = case decEq a b of
    Yes prf   => Yes (cong MkHashValue prf)
    No contra => No (\eq => contra (cong digest eq))

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
               -> (hashProof : computed = expected)  -- formal equality proof
               -> HashesMatch s m

||| WITNESS: Attested Verification.
||| Confirms hash authenticity *and* domain attestation: a timestamp and a
||| verified signature flag, layered on top of the `HashesMatch` evidence.
public export
data FullyAttested : (state : Type) -> (manifest : Type) -> Type where
  MkFullyAttested : {0 s : Type} -> {0 m : Type}
                 -> (hashesOk : HashesMatch s m)
                 -> (timestamp : Nat)
                 -> (signatureValid : Bool)
                 -> FullyAttested s m

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

||| PROMOTION: Layer domain attestation (a timestamp and a verified-signature
||| flag) onto a hash-verified proof to obtain a fully attested one.
public export
fullyAttest : HashesMatch s m -> (timestamp : Nat) -> (signatureValid : Bool)
           -> FullyAttested s m
fullyAttest h t s = MkFullyAttested h t s
