# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Ochránce Framework — Build Recipes
# https://just.systems/man/en/

set shell := ["bash", "-uc"]
set dotenv-load := true
set positional-arguments := true

# Import auto-generated contractile recipes
import? "contractile.just"

# Project metadata
project := "ochrance-framework"
version := "0.1.0"
tier := "infrastructure"

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT & HELP
# ═══════════════════════════════════════════════════════════════════════════════

# Show all available recipes
default:
    @just --list --unsorted

# Show this project's info
info:
    @echo "Project: Ochránce (ochrance-framework)"
    @echo "Version: {{ version }}"
    @echo "RSR Tier: {{ tier }}"
    @echo "Language: Idris2 + C (thin FFI)"
    @echo "Recipes: $(just --summary | wc -w)"
    @[ -f ".machine_readable/STATE.a2ml" ] && grep -oP 'phase\s*=\s*"\K[^"]+' .machine_readable/STATE.a2ml | head -1 | xargs -I{} echo "Phase: {}" || true

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD
# ═══════════════════════════════════════════════════════════════════════════════

# Build the Ochránce framework (Idris2 + C shims)
build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building Ochránce..."

    # Build C shims
    echo "  Compiling C shims..."
    gcc -c -Wall -Wextra -O2 ffi/c/nvme_shim.c -o build/nvme_shim.o 2>/dev/null || \
        echo "  (C shims skipped - missing headers or gcc)"

    # Build Idris2
    echo "  Compiling Idris2..."
    idris2 --build ochrance.ipkg
    echo "Build complete."

# Build C shims only
build-c:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p build
    gcc -c -Wall -Wextra -Wpedantic -O2 \
        -I ffi/c \
        ffi/c/nvme_shim.c \
        -o build/nvme_shim.o
    echo "C shims compiled: build/nvme_shim.o"

# Build Idris2 only
build-idris:
    idris2 --build ochrance.ipkg

# Clean build artifacts
clean:
    rm -rf build/ output/ *.ibc *.ttc *.ttm
    echo "Cleaned."

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK & TEST
# ═══════════════════════════════════════════════════════════════════════════════

# Type-check all Idris2 modules (no compilation)
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Type-checking Ochránce modules..."
    find ochrance-core -name '*.idr' | while read -r f; do
        echo "  Checking: $f"
        idris2 --check "$f" --source-dir ochrance-core || exit 1
    done
    echo "All modules type-check."

# Verify totality of critical functions
check-totality:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Verifying totality..."
    # Check that parser and verification functions are marked total
    for f in ochrance-core/A2ML/Lexer.idr ochrance-core/A2ML/Parser.idr; do
        if [ -f "$f" ]; then
            if grep -q "^total" "$f" || grep -q "^export total" "$f"; then
                echo "  $f: total annotations present"
            else
                echo "  WARNING: $f missing total annotations"
            fi
        fi
    done

# Run the test suite
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running Ochránce tests..."
    if [ -f tests/ochrance-tests.ipkg ]; then
        idris2 --build tests/ochrance-tests.ipkg
        build/exec/ochrance-tests
    else
        echo "  No test package found (tests/ochrance-tests.ipkg)"
        echo "  Run: just check (for type-checking)"
    fi

# Run property-based tests
test-properties:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running property-based tests..."
    if [ -d tests/properties ]; then
        find tests/properties -name '*.idr' -exec idris2 --check {} \;
    else
        echo "  No property tests found yet."
    fi

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFY (Ochránce-specific)
# ═══════════════════════════════════════════════════════════════════════════════

# Verify a filesystem against an A2ML manifest
verify manifest="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ manifest }}" ]; then
        echo "Usage: just verify <manifest.a2ml>"
        exit 1
    fi
    echo "Verifying filesystem against: {{ manifest }}"
    ochrance verify --manifest="{{ manifest }}" --mode=Checked

# Generate an A2ML manifest for a path
attest path="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ path }}" ]; then
        echo "Usage: just attest <path>"
        exit 1
    fi
    echo "Generating A2ML manifest for: {{ path }}"
    ochrance attest --path="{{ path }}" --output="manifest.a2ml"

# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK
# ═══════════════════════════════════════════════════════════════════════════════

# Run performance benchmarks
bench:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running Ochránce benchmarks..."
    if [ -d benchmarks ]; then
        cd benchmarks && idris2 --build bench.ipkg && ./build/exec/bench
    else
        echo "  No benchmarks found yet."
    fi

# ═══════════════════════════════════════════════════════════════════════════════
# ECHIDNA INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

# Run Echidna proof synthesis on a theorem
echidna-prove theorem="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ theorem }}" ]; then
        echo "Usage: just echidna-prove '<theorem>'"
        exit 1
    fi
    echo "Synthesizing proof via Echidna..."
    echidna synthesize --prover idris2 "{{ theorem }}"

# Verify a proof with Echidna's Idris2 backend
echidna-verify proof="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ proof }}" ]; then
        echo "Usage: just echidna-verify <proof.idr>"
        exit 1
    fi
    echidna verify --prover idris2 "{{ proof }}"

# ═══════════════════════════════════════════════════════════════════════════════
# DOCUMENTATION
# ═══════════════════════════════════════════════════════════════════════════════

# Generate documentation
docs:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Generating Ochránce documentation..."
    if command -v idris2 &>/dev/null; then
        idris2 --mkdoc ochrance.ipkg 2>/dev/null || echo "  (idris2 --mkdoc not available)"
    fi
    echo "Documentation in docs/"

# ═══════════════════════════════════════════════════════════════════════════════
# RSR COMPLIANCE
# ═══════════════════════════════════════════════════════════════════════════════

# Check RSR compliance
rsr-check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking RSR compliance..."
    ok=0; fail=0

    check() {
        if [ -e "$1" ]; then
            echo "  [OK] $1"
            ok=$((ok + 1))
        else
            echo "  [MISSING] $1"
            fail=$((fail + 1))
        fi
    }

    check ".editorconfig"
    check ".gitignore"
    check ".gitattributes"
    check "CODE_OF_CONDUCT.md"
    check "CONTRIBUTING.md"
    check "SECURITY.md"
    check "LICENSE"
    check "0-AI-MANIFEST.a2ml"
    check "TOPOLOGY.md"
    check "Justfile"
    check ".machine_readable/STATE.a2ml"
    check ".machine_readable/META.a2ml"
    check ".machine_readable/ECOSYSTEM.a2ml"
    check ".machine_readable/AGENTIC.a2ml"
    check ".machine_readable/NEUROSYM.a2ml"
    check ".machine_readable/PLAYBOOK.a2ml"

    # Check NO SCM files in root
    for scm in STATE.a2ml META.a2ml ECOSYSTEM.a2ml AGENTIC.a2ml NEUROSYM.a2ml PLAYBOOK.a2ml; do
        if [ -f "$scm" ]; then
            echo "  [VIOLATION] $scm in root (must be in .machine_readable/)"
            fail=$((fail + 1))
        fi
    done

    echo ""
    echo "Results: $ok passed, $fail failed"
    [ "$fail" -eq 0 ] && echo "RSR compliant." || echo "RSR violations found!"

# Validate SPDX headers
spdx-check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking SPDX headers..."
    missing=0
    find ochrance-core -name '*.idr' | while read -r f; do
        if ! head -1 "$f" | grep -q "SPDX-License-Identifier"; then
            echo "  MISSING: $f"
            missing=$((missing + 1))
        fi
    done
    [ "$missing" -eq 0 ] && echo "All files have SPDX headers." || echo "$missing files missing SPDX."

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"

# Self-diagnostic — checks dependencies, permissions, paths
doctor:
    @echo "Running diagnostics for ochrance-framework..."
    @echo "Checking required tools..."
    @command -v just >/dev/null 2>&1 && echo "  [OK] just" || echo "  [FAIL] just not found"
    @command -v git >/dev/null 2>&1 && echo "  [OK] git" || echo "  [FAIL] git not found"
    @echo "Checking for hardcoded paths..."
    @grep -rn '$HOME\|$ECLIPSE_DIR' --include='*.rs' --include='*.ex' --include='*.res' --include='*.gleam' --include='*.sh' . 2>/dev/null | head -5 || echo "  [OK] No hardcoded paths"
    @echo "Diagnostics complete."

# Auto-repair common issues
heal:
    @echo "Attempting auto-repair for ochrance-framework..."
    @echo "Fixing permissions..."
    @find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    @echo "Cleaning stale caches..."
    @rm -rf .cache/stale 2>/dev/null || true
    @echo "Repair complete."

# Guided tour of key features
tour:
    @echo "=== ochrance-framework Tour ==="
    @echo ""
    @echo "1. Project structure:"
    @ls -la
    @echo ""
    @echo "2. Available commands: just --list"
    @echo ""
    @echo "3. Read README.adoc for full overview"
    @echo "4. Read EXPLAINME.adoc for architecture decisions"
    @echo "5. Run 'just doctor' to check your setup"
    @echo ""
    @echo "Tour complete! Try 'just --list' to see all available commands."

# Open feedback channel with diagnostic context
help-me:
    @echo "=== ochrance-framework Help ==="
    @echo "Platform: $(uname -s) $(uname -m)"
    @echo "Shell: $SHELL"
    @echo ""
    @echo "To report an issue:"
    @echo "  https://github.com/hyperpolymath/ochrance-framework/issues/new"
    @echo ""
    @echo "Include the output of 'just doctor' in your report."
