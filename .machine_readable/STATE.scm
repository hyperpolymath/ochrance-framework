; SPDX-License-Identifier: PMPL-1.0-or-later
; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

(state
  (metadata
    (version "0.1.0")
    (project "ochrance-framework")
    (updated "2026-03-20"))

  (project-context
    (description "Modular verification framework for subsystem integrity using dependent types")
    (language "Idris2")
    (modules ("filesystem" "memory" "network" "crypto"))
    (completion-estimate "10%"))

  (tangle-resolution
    (status "resolved")
    (date "2026-03-20")
    (classification "complementary")
    (relationship "ochrance-framework defines the abstract architecture; ochrance is the reference implementation of the Filesystem module")
    (sibling-repo "ochrance")
    (notes "P0 tangle resolved — these are complementary repos, not duplicates. ochrance-framework defines the VerifiedSubsystem interface and four subsystem modules; ochrance provides the concrete filesystem implementation."))

  (current-position
    (phase "design")
    (milestone "framework-architecture")
    (blockers '()))

  (critical-next-actions
    (action "Stabilize VerifiedSubsystem interface based on ochrance learnings")
    (action "Design Memory module specification")
    (action "Extract common patterns from ochrance into framework")))
