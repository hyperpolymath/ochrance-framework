-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Filesystem.Repair
|||
||| Repair logic for the filesystem subsystem.
|||
||| When verification fails, the repair module restores the filesystem
||| to a known-good state from a snapshot. Repair is designed to be
||| atomic: either the entire repair succeeds, or the state is unchanged.
|||
||| Key design decisions:
|||   - Linear types ensure the corrupt state is consumed (not reused)
|||   - Snapshots are opaque blobs decoded by the filesystem module
|||   - Repair operates block-by-block to minimise I/O
|||   - Failed repairs leave the original state intact

module Ochrance.Filesystem.Repair

import Ochrance.Framework.Interface
import Ochrance.Framework.Error
import Ochrance.Filesystem.Types
import Ochrance.Filesystem.Merkle
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Repair strategy
--------------------------------------------------------------------------------

||| Strategy for repair: which blocks need to be restored.
public export
data RepairStrategy : Type where
  ||| Replace all blocks from snapshot (full restore).
  FullRestore  : RepairStrategy
  ||| Replace only blocks whose hashes don't match (incremental).
  Incremental  : (corruptIndices : List Nat) -> RepairStrategy
  ||| Reconstruct from parity/redundancy (RAID-like).
  Reconstruct  : RepairStrategy

||| Show instance for repair strategies.
public export
Show RepairStrategy where
  show FullRestore         = "full-restore"
  show (Incremental idxs)  = "incremental(" ++ show (length idxs) ++ " blocks)"
  show Reconstruct         = "reconstruct"

--------------------------------------------------------------------------------
-- Repair result
--------------------------------------------------------------------------------

||| Outcome of a repair operation.
public export
data RepairResult : Type where
  ||| Repair succeeded; new state is ready for re-verification.
  RepairOk      : (blocksRestored : Nat) -> RepairResult
  ||| Repair failed; original state is unchanged.
  RepairFailed  : (reason : String) -> RepairResult
  ||| Snapshot was incompatible with current filesystem layout.
  SnapshotIncompatible : (expected : Nat) -> (snapshotBlocks : Nat) -> RepairResult

||| Show instance for repair results.
public export
Show RepairResult where
  show (RepairOk n)                = "repair-ok: " ++ show n ++ " blocks restored"
  show (RepairFailed r)            = "repair-failed: " ++ r
  show (SnapshotIncompatible e s)  = "snapshot-incompatible: expected "
                                   ++ show e ++ " blocks, snapshot has " ++ show s

--------------------------------------------------------------------------------
-- Snapshot decoding
--------------------------------------------------------------------------------

||| Decoded snapshot: a list of blocks extracted from the snapshot payload.
||| The snapshot format is subsystem-specific; this is the filesystem's
||| interpretation of the opaque payload bytes.
public export
record DecodedSnapshot (n : Nat) where
  constructor MkDecodedSnapshot
  ||| Restored blocks.
  snapshotBlocks : Vect n Block
  ||| Restored metadata.
  snapshotMeta   : Vect n BlockMetadata
  ||| Snapshot creation timestamp.
  snapshotTime   : Bits64

||| Attempt to decode a snapshot payload into filesystem blocks.
|||
||| TODO: Implement actual snapshot format parsing.
||| For now, returns a placeholder failure.
|||
||| @expected  Expected number of blocks
||| @payload   Raw snapshot bytes
public export
decodeSnapshot : (expected : Nat) -> List Bits8 -> Maybe (DecodedSnapshot expected)
decodeSnapshot expected payload =
  -- TODO: Implement snapshot format:
  --   [4 bytes: block count]
  --   [4 bytes: block size]
  --   [8 bytes: timestamp]
  --   [n * blockSize bytes: block data]
  --   [n * metadata_size bytes: metadata]
  Nothing

--------------------------------------------------------------------------------
-- Identifying corrupt blocks
--------------------------------------------------------------------------------

||| Compare state block hashes against a manifest to find corrupt blocks.
|||
||| Returns a list of indices where the block hash does not match.
|||
||| TODO: Use Fin n instead of Nat for type-safe indexing.
public export
findCorruptBlocks : {n : Nat} -> FSState n -> Vect n String -> List Nat
findCorruptBlocks st expectedHashes =
  findMismatches 0 (toList (map blockHash st.blocks)) (toList expectedHashes)
  where
    findMismatches : Nat -> List String -> List String -> List Nat
    findMismatches _ []        _         = []
    findMismatches _ _         []        = []
    findMismatches idx (a :: as) (e :: es) =
      if a == e
      then findMismatches (idx + 1) as es
      else idx :: findMismatches (idx + 1) as es

--------------------------------------------------------------------------------
-- Core repair logic
--------------------------------------------------------------------------------

||| Perform a full restore from a decoded snapshot.
|||
||| Replaces all blocks and metadata in the state with snapshot data.
||| The corrupt state is consumed (linear usage pattern).
|||
||| @corrupt   The corrupt filesystem state (consumed)
||| @snapshot  The decoded snapshot to restore from
||| @return    A new FSState built from the snapshot
public export
fullRestore : {n : Nat}
           -> (corrupt : FSState n)
           -> DecodedSnapshot n
           -> FSState n
fullRestore corrupt snap =
  MkFSState snap.snapshotBlocks snap.snapshotMeta n Refl

||| Perform an incremental repair: only replace blocks at specified indices.
|||
||| TODO: Implement incremental block replacement using Fin-indexed access.
||| For now, falls back to full restore.
|||
||| @corrupt   The corrupt filesystem state
||| @snapshot  The decoded snapshot
||| @indices   List of block indices to replace
||| @return    The repaired FSState
public export
incrementalRepair : {n : Nat}
                 -> (corrupt : FSState n)
                 -> DecodedSnapshot n
                 -> (indices : List Nat)
                 -> FSState n
incrementalRepair corrupt snap indices =
  -- TODO: Replace only blocks at the specified indices.
  -- For now, fall back to full restore for correctness.
  fullRestore corrupt snap

--------------------------------------------------------------------------------
-- Public repair API
--------------------------------------------------------------------------------

||| Repair a corrupt filesystem state from a snapshot.
|||
||| This is the IO-bound entry point called by the VerifiedSubsystem
||| interface. It decodes the snapshot, determines the repair strategy,
||| and applies the appropriate repair operation.
|||
||| @corrupt  The corrupt FSState
||| @snap     The opaque Snapshot from the framework
||| @return   Either a repaired FSState or an error
public export
repairFS : {n : Nat} -> FSState n -> Snapshot -> IO (Either RepairResult (FSState n))
repairFS corrupt snap = do
  case decodeSnapshot n snap.payload of
    Nothing =>
      pure (Left (RepairFailed "could not decode snapshot"))
    Just decoded => do
      let repaired = fullRestore corrupt decoded
      pure (Right repaired)
