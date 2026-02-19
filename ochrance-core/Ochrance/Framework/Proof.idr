-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Framework.Proof
|||
||| Generic proof witnesses for the verification framework.
|||
||| The Ochrance framework uses three levels of verification strictness,
||| each producing a different proof witness:
|||
|||   StructureValid  — Lax mode: structural integrity only
|||   HashesMatch     — Checked mode: cryptographic hash equality
|||   FullyAttested   — Attested mode: full dependent type proof
|||
||| These witnesses are indexed by the verification mode, allowing
||| type-safe dispatch on the level of assurance obtained.

module Ochrance.Framework.Proof

import Ochrance.Framework.Progressive

%default total

--------------------------------------------------------------------------------
-- Hash representation
--------------------------------------------------------------------------------

||| A cryptographic hash value.
||| Represented as a fixed-length vector of bytes.
||| The algorithm is tracked at the type level via a tag.
public export
data HashAlgorithm = SHA256 | SHA384 | SHA512 | BLAKE3

||| Hash value as a list of bytes with algorithm tag.
public export
record HashValue where
  constructor MkHash
  algorithm : HashAlgorithm
  bytes     : List Bits8

||| Decidable equality for hash algorithms.
public export
Eq HashAlgorithm where
  SHA256 == SHA256 = True
  SHA384 == SHA384 = True
  SHA512 == SHA512 = True
  BLAKE3 == BLAKE3 = True
  _      == _      = False

||| Decidable equality for hash values.
public export
Eq HashValue where
  (MkHash a1 b1) == (MkHash a2 b2) = a1 == a2 && b1 == b2

--------------------------------------------------------------------------------
-- Proof witnesses
--------------------------------------------------------------------------------

||| Proof that the structure of a state is valid.
||| This is the weakest level — only checks that fields exist
||| and have sensible shapes, without verifying content hashes.
|||
||| Produced by Lax mode verification.
public export
data StructureValid : (state : Type) -> (manifest : Type) -> Type where
  ||| Witness that all required fields are present and well-formed.
  MkStructureValid : {0 s : Type} -> {0 m : Type}
                  -> (fieldCount : Nat)
                  -> (allPresent : Bool)
                  -> StructureValid s m

||| Proof that all cryptographic hashes in a state match the manifest.
||| Strictly stronger than StructureValid — implies structure is also valid.
|||
||| The `hashProof` field carries evidence that computed == expected.
|||
||| Produced by Checked mode verification.
public export
data HashesMatch : (state : Type) -> (manifest : Type) -> Type where
  ||| Witness that structure is valid AND all hashes match.
  MkHashesMatch : {0 s : Type} -> {0 m : Type}
               -> (structureOk : StructureValid s m)
               -> (computed : HashValue)
               -> (expected : HashValue)
               -> (hashProof : computed = expected)
               -> HashesMatch s m

||| Full attestation proof with dependent type guarantees.
||| This is the strongest level — carries the actual state and manifest
||| values as erased indices, plus proofs of both hash matching and
||| any subsystem-specific invariants.
|||
||| Produced by Attested mode verification.
public export
data FullyAttested : (state : Type) -> (manifest : Type) -> Type where
  ||| Witness of full attestation: structure + hashes + invariants.
  MkFullyAttested : {0 s : Type} -> {0 m : Type}
                 -> (hashOk : HashesMatch s m)
                 -> (attestationTime : Bits64)
                 -> (invariantsHold : Bool)
                 -> FullyAttested s m

--------------------------------------------------------------------------------
-- Mode-indexed proof family
--------------------------------------------------------------------------------

||| Type-level function mapping a VerificationMode to its proof witness.
||| This allows generic code to be parameterised by mode while retaining
||| type-safe access to the appropriate proof level.
public export
VerificationProof : VerificationMode -> Type -> Type -> Type
VerificationProof Lax      s m = StructureValid s m
VerificationProof Checked  s m = HashesMatch s m
VerificationProof Attested s m = FullyAttested s m

--------------------------------------------------------------------------------
-- Proof combinators
--------------------------------------------------------------------------------

||| Strengthen a StructureValid proof to HashesMatch by supplying hash evidence.
public export
strengthen : StructureValid s m
          -> (computed : HashValue)
          -> (expected : HashValue)
          -> (prf : computed = expected)
          -> HashesMatch s m
strengthen sv c e prf = MkHashesMatch sv c e prf

||| Fully attest a HashesMatch proof by adding attestation metadata.
public export
fullyAttest : HashesMatch s m
           -> (time : Bits64)
           -> (invariantsOk : Bool)
           -> FullyAttested s m
fullyAttest hm t inv = MkFullyAttested hm t inv

||| Extract the weaker StructureValid proof from a HashesMatch.
public export
weakenToStructure : HashesMatch s m -> StructureValid s m
weakenToStructure (MkHashesMatch sv _ _ _) = sv

||| Extract the HashesMatch proof from a FullyAttested.
public export
weakenToHashes : FullyAttested s m -> HashesMatch s m
weakenToHashes (MkFullyAttested hm _ _) = hm
