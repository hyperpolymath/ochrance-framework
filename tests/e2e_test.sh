#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
# e2e_test.sh — Structural E2E tests for ochrance-framework (Ochránce).

set -euo pipefail
PASS=0; FAIL=0; BASE=/var/mnt/eclipse/repos/ochrance-framework

assert() {
  if [[ "$2" == "0" ]]; then echo "PASS: $1"; PASS=$((PASS+1))
  else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi
}

echo "=== E2E: 6-Layer Trust Pyramid Structure ==="
# L2: Merkle Root + A2ML (Idris2)
assert "A2ML Types.idr exists (L2)" "$([ -f "$BASE/ochrance-core/Ochrance/A2ML/Types.idr" ] && echo 0 || echo 1)"
assert "A2ML Parser.idr exists (L2)" "$([ -f "$BASE/ochrance-core/Ochrance/A2ML/Parser.idr" ] && echo 0 || echo 1)"
assert "Framework Interface.idr exists" "$([ -f "$BASE/ochrance-core/Ochrance/Framework/Interface.idr" ] && echo 0 || echo 1)"
assert "Framework Proof.idr exists" "$([ -f "$BASE/ochrance-core/Ochrance/Framework/Proof.idr" ] && echo 0 || echo 1)"

# L1: C shims
assert "C FFI shim exists (L1)" "$([ -f "$BASE/ffi/c/nvme_shim.c" ] && echo 0 || echo 1)"

echo ""
echo "=== E2E: Framework Invariants ==="
# All Idris2 files should have %default total or total annotations
total_count=$(grep -rl "%default total\|: .* -> .* total" "$BASE/ochrance-core" 2>/dev/null | wc -l || true)
assert "Total annotations present in Idris2 source ($total_count files)" "$([ "$total_count" -gt 0 ] && echo 0 || echo 1)"

# VerifiedSubsystem interface exists
assert "VerifiedSubsystem interface defined" \
  "$(grep -q "VerifiedSubsystem\|interface.*Verified" "$BASE/ochrance-core/Ochrance/Framework/Interface.idr" && echo 0 || echo 1)"

# Proof types defined
assert "Proof data type defined" \
  "$(grep -q "^data Proof\|Proof.*Type\|record Proof" "$BASE/ochrance-core/Ochrance/Framework/Proof.idr" && echo 0 || echo 1)"

echo ""
echo "=== E2E: Code Quality ==="
idr_files=$(find "$BASE/ochrance-core" -name "*.idr" | wc -l)
assert "Idris2 source files present ($idr_files)" "$([ "$idr_files" -gt 0 ] && echo 0 || echo 1)"
spdx_count=$(find "$BASE/ochrance-core" -name "*.idr" | xargs grep -l "SPDX-License-Identifier" 2>/dev/null | wc -l)
assert "Idris2 files have SPDX ($spdx_count/$idr_files)" "$([ "$spdx_count" -eq "$idr_files" ] && echo 0 || echo 1)"

# No dangerous patterns
unsafe_count=$(grep -r "believe_me\|assert_total\|unsafePerformIO" "$BASE/ochrance-core" 2>/dev/null | wc -l || true)
assert "No unsafe Idris2 patterns ($unsafe_count found)" "$([ "$unsafe_count" -eq 0 ] && echo 0 || echo 1)"

echo ""
echo "=== E2E: Documentation ==="
for f in README.adoc LICENSE TEST-NEEDS.md; do
  assert "$f exists" "$([ -f "$BASE/$f" ] && echo 0 || echo 1)"
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
