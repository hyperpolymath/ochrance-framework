-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

||| Ochrance.Filesystem.Merkle
|||
||| Merkle tree construction and verification for filesystem integrity.
|||
||| A Merkle tree is a binary hash tree where:
|||   - Leaves contain the hash of a single data block
|||   - Internal nodes contain the hash of their children's concatenated hashes
|||   - The root hash summarises the entire dataset
|||
||| All functions in this module are total. Tree construction uses
||| structural recursion on the input list, and verification uses
||| structural recursion on the proof path.

module Ochrance.Filesystem.Merkle

import Data.List

%default total

--------------------------------------------------------------------------------
-- Merkle tree data type
--------------------------------------------------------------------------------

||| A Merkle tree node.
|||
||| The tree is binary: each internal node has exactly two children.
||| Leaves carry a hash derived from a single data block.
||| Nodes carry a hash derived from their children.
public export
data MerkleTree : Type where
  ||| A leaf node containing a single block's hash.
  Leaf : (hash : String) -> MerkleTree
  ||| An internal node with two children and a combined hash.
  Node : (hash : String) -> (left : MerkleTree) -> (right : MerkleTree) -> MerkleTree

||| Extract the root hash from any Merkle tree node.
public export
rootHash : MerkleTree -> String
rootHash (Leaf h)     = h
rootHash (Node h _ _) = h

--------------------------------------------------------------------------------
-- Hash combining (placeholder)
--------------------------------------------------------------------------------

||| Combine two hashes to produce a parent hash.
|||
||| In a real implementation this would use SHA-256 or BLAKE3.
||| For now we use string concatenation as a placeholder.
|||
||| TODO: Replace with actual cryptographic hash via FFI.
combineHashes : String -> String -> String
combineHashes left right = "H(" ++ left ++ "|" ++ right ++ ")"

||| Compute the hash of a leaf (block data hash).
|||
||| TODO: Replace with actual cryptographic hash via FFI.
hashLeaf : String -> String
hashLeaf blockHash = blockHash

--------------------------------------------------------------------------------
-- Tree construction
--------------------------------------------------------------------------------

||| Build a Merkle tree from a list of block hashes.
|||
||| Total by fuel-bounded recursion: the fuel parameter decreases at
||| each recursive call, guaranteeing termination. Fuel is initialised
||| to the length of the input list, which is always sufficient since
||| each recursive call operates on a strictly smaller list.
|||
||| Special cases:
|||   - Empty list:    returns a Leaf with empty hash
|||   - Single hash:   returns a Leaf
|||   - Multiple:      splits in half, recurses, combines
|||
||| @hashes  List of per-block hashes
||| @return  A MerkleTree whose root hash summarises all inputs
public export
buildMerkleTree : List String -> MerkleTree
buildMerkleTree hs = buildWithFuel (length hs) hs
  where
    ||| Fuel-bounded tree construction.
    ||| @fuel  Decreasing natural number guaranteeing termination
    ||| @hs    Block hashes to build from
    buildWithFuel : Nat -> List String -> MerkleTree
    buildWithFuel Z     _       = Leaf ""
    buildWithFuel _     []      = Leaf ""
    buildWithFuel _     [h]     = Leaf (hashLeaf h)
    buildWithFuel (S k) hs      =
      let len   = length hs
          mid   = div len 2
          left  = take mid hs
          right = drop mid hs
          leftTree  = buildWithFuel k left
          rightTree = buildWithFuel k right
          combined  = combineHashes (rootHash leftTree) (rootHash rightTree)
      in Node combined leftTree rightTree

--------------------------------------------------------------------------------
-- Merkle proof (inclusion proof)
--------------------------------------------------------------------------------

||| A Merkle proof is a path from a leaf to the root.
||| Each step records whether the sibling was on the left or right,
||| and what the sibling's hash was.
public export
data MerkleProofStep : Type where
  ||| The sibling is on the left; this node was on the right.
  SiblingLeft  : (siblingHash : String) -> MerkleProofStep
  ||| The sibling is on the right; this node was on the left.
  SiblingRight : (siblingHash : String) -> MerkleProofStep

||| A complete Merkle proof: the leaf hash plus the path to the root.
public export
record MerkleProof where
  constructor MkMerkleProof
  ||| The hash of the leaf being proven.
  leafHash : String
  ||| The path from leaf to root.
  path     : List MerkleProofStep

--------------------------------------------------------------------------------
-- Proof verification
--------------------------------------------------------------------------------

||| Verify a Merkle proof against an expected root hash.
|||
||| Walks the proof path from leaf to root, combining hashes at each step,
||| and checks that the result matches the expected root.
|||
||| Total by structural recursion on the proof path.
|||
||| @proof       The Merkle inclusion proof
||| @expectedRoot The expected root hash to verify against
||| @return      True if the proof is valid
public export
verifyMerkleProof : MerkleProof -> (expectedRoot : String) -> Bool
verifyMerkleProof proof expectedRoot =
  let computedRoot = foldl applyStep proof.leafHash proof.path
  in computedRoot == expectedRoot
  where
    ||| Apply a single proof step: combine with sibling hash.
    applyStep : String -> MerkleProofStep -> String
    applyStep current (SiblingLeft sibling)  = combineHashes sibling current
    applyStep current (SiblingRight sibling) = combineHashes current sibling

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------

||| Count the number of leaves in a Merkle tree.
public export
leafCount : MerkleTree -> Nat
leafCount (Leaf _)     = 1
leafCount (Node _ l r) = leafCount l + leafCount r

||| Collect all leaf hashes in order (left-to-right traversal).
public export
leaves : MerkleTree -> List String
leaves (Leaf h)     = [h]
leaves (Node _ l r) = leaves l ++ leaves r

||| Compute the depth of the tree.
public export
depth : MerkleTree -> Nat
depth (Leaf _)     = 0
depth (Node _ l r) = 1 + max (depth l) (depth r)
