-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Filesystem.Types
|||
||| Core types for the filesystem verification subsystem.
|||
||| The filesystem subsystem models storage as a collection of blocks,
||| each identified by an index and carrying a payload of raw bytes.
||| Integrity is tracked via Merkle trees: each block has a hash,
||| and these hashes combine into a root hash stored in the manifest.
|||
||| Types defined here:
|||   BlockIndex   — Bounded block identifier
|||   Block        — A single storage block with data and hash
|||   FSState      — The runtime state of the filesystem subsystem
|||   FSManifest   — The integrity manifest (root hash + block hashes)

module Ochrance.Filesystem.Types

import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Block types
--------------------------------------------------------------------------------

||| Block size in bytes. Fixed at 4096 (standard page size).
public export
BlockSize : Nat
BlockSize = 4096

||| A block index, bounded by the total number of blocks.
||| The Fin type ensures the index is always in range.
public export
BlockIndex : Nat -> Type
BlockIndex n = Fin n

||| A single storage block.
public export
record Block where
  constructor MkBlock
  ||| Raw block data as a list of bytes.
  ||| In a real implementation this would be a ByteArray or Buffer.
  blockData : List Bits8
  ||| Hash of the block data (hex-encoded).
  blockHash : String

||| Metadata associated with a block (timestamps, permissions, etc.).
public export
record BlockMetadata where
  constructor MkBlockMetadata
  ||| Last modification time (Unix epoch seconds).
  modifiedAt : Bits64
  ||| Owner identifier.
  owner      : String
  ||| Whether the block is marked as read-only.
  readOnly   : Bool

--------------------------------------------------------------------------------
-- Filesystem state
--------------------------------------------------------------------------------

||| The runtime state of the filesystem subsystem.
|||
||| Parameterised by the total number of blocks, which is known
||| at verification time. The Vect type ensures the block vector
||| has exactly the right length.
public export
record FSState (n : Nat) where
  constructor MkFSState
  ||| The block storage, indexed by position.
  blocks     : Vect n Block
  ||| Per-block metadata.
  metadata   : Vect n BlockMetadata
  ||| Total number of blocks (redundant with n, but useful at runtime).
  totalBlocks : Nat
  ||| Proof that totalBlocks equals n.
  blockCountPrf : totalBlocks = n

--------------------------------------------------------------------------------
-- Filesystem manifest
--------------------------------------------------------------------------------

||| The integrity manifest for the filesystem subsystem.
|||
||| Contains the Merkle root hash (computed from all block hashes)
||| and the per-block hashes for individual block verification.
public export
record FSManifest (n : Nat) where
  constructor MkFSManifest
  ||| Merkle root hash over all block hashes.
  rootHash    : String
  ||| Per-block hashes, in order.
  blockHashes : Vect n String
  ||| Manifest format version for compatibility checking.
  version     : String

--------------------------------------------------------------------------------
-- Smart constructors
--------------------------------------------------------------------------------

||| Create an FSState with zero blocks.
public export
emptyFSState : FSState 0
emptyFSState = MkFSState [] [] 0 Refl

||| Create an FSManifest for zero blocks.
public export
emptyFSManifest : FSManifest 0
emptyFSManifest = MkFSManifest "" [] "1.0.0"
