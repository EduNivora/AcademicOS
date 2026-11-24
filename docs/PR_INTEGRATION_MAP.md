# AcademicOS — PR Integration Map

**Baseline:** `main@989ad5212971097df868dabab557c1c076d91720`  
**Snapshot:** 2026-11-24

## Integration dependencies and overlaps

| PR | Base → head | Shared files / dependency | Decision |
|---|---|---|---|
| #47 Gemini quotas | main → `feat/ai-durable-account-quotas` | Neon backend workflow, package scripts, Neon README and AI function | Keep isolated. Requires migration review and fresh Flutter CI; do not deploy. |
| #50 QA candidate | main → `qa/uiux-release-candidate` | Flutter workflow, DB helper/schema tests, assistant executor/screen and UI | Conflict reported by GitHub (mergeable=false). Resolve/rebase before acceptance. |
| #53 guest metrics | main → `feat/guest-metrics-edge-gateway-mainline` | Flutter + Neon workflows and Neon notices backend | CI passed on exact head, but deployment prerequisites remain. Its workflow overlaps #60 and #50. |
| #57 Flutter pipefail | main → `fix/main-flutter-test-pipefail` (closed) | Only `.github/workflows/flutter-quality.yml`; same file as #50/#53/#60 | Closed as superseded by #60 after its strict pipefail, 4-core/4096-MB emulator sizing and Package Manager readiness changes were incorporated. |
| #58 attachment reopen test | main → `test/attachment-close-reopen-mainline` | `test/database_schema_test.dart`; same test file also touched by QA/attachment work | Keep separate and revalidate; do not infer BLOB architecture approval from this test. |
| #59 assistant postconditions | QA #50 → `feat/assistant-postcondition-verification-qa-rebased` | Assistant executor, assistant screen, schedule screen, acceptance docs | Stacked on QA, not main. Integrate only after #50 base is resolved and the stack is deliberately replayed/rebased. |
| #60 Phase 0 baseline | main → `chore/phase0-baseline-ci-hardening` | Flutter quality workflow and baseline/integration/risk/acceptance docs | Active; exact head `d4962ea...`, mergeable. Wait for exact-head CI including Android SQLite and build gates. |
| #68 Phase 1 backup removal | #60 Phase 0 → `feat/phase1-remove-backup-separate-reports-v8` | Reports service/screen, database helper, validator, restore-only tests, product and acceptance docs | Active; synchronized with #60 head `d4962ea...`; do not merge until exact-head CI passes. |
| #52 assistant postconditions (older) | QA → `feat/assistant-postcondition-verification` | Same assistant executor/screen as #59 | Superseded by rebased #59 candidate; do not merge both. |
| #54 attachment persistence proof | main → `test/durable-course-attachment-persistence` | Android integration test and attachment BLOB path | Compare with #58 before integrating; avoid duplicate test assertions. |
| #55 assistant postconditions (older) | QA → `feat/assistant-postcondition-verification-current-qa` | Same assistant files as #59 | Closed unmerged; historical source only. #59 is the current rebased candidate. |
| #56 QA pipefail | QA → `fix/qa-flutter-test-pipefail` | Flutter workflow | Merged into QA only; not main. Do not treat as mainline fix. |
| #17 attachment storage | historical phase0 branch → durable attachment branch | DB helper, BLOB persistence, backup serialization | Already merged into the phase0 integration line; BLOB implementation is current persistence evidence, not a final architecture decision. |
| #18–#20 backup archive / Drive | phase0 / encrypted archive stack | Backup archive, crypto and Drive integration | Closed after the product owner excluded backup/restore from AcademicOS. Branches remain as Git history only; do not merge. |
| #13 attachment path guard | phase0 integration line | Material path and PDF viewer | Historical mitigation. Its stale base and backup-era references must not be pulled into the current mainline without re-review. |

## Suggested integration order

1. Merge PR #60 only after its exact-head CI passes, including the Android SQLite gate.
2. Merge PR #68 only after it is synchronized to #60 and its own exact-head CI passes; it is intentionally stacked on Phase 0.
3. Resolve #50 against current main and rerun its complete quality gate; only then consider #59 and its assistant-stack dependencies.
4. Review #58 and #54 together for duplicate coverage; merge only the minimal proven test set.
5. Keep #47 and #53 separate from Flutter UI stacks. Their backend CI does not authorize migrations, secrets, or deployment.
6. Keep #18–#20 and superseded #61–#67 closed out of the Release 1 integration path.

## Repository-wide inventory

The current repository API snapshot contains 62 PRs (34 open, 28 closed, 12 merged). The active PRs and branches that directly affect the current integration sequence are enumerated above. The remaining active PRs are separate release, authentication, web-runtime, database, UI, and historical phase0 stacks; their base branches are not interchangeable with main. Do not mass-merge them as a batch.


## Execution update — after Phase 0 / Phase 1 PR creation

The comparisons below use the then-current main SHA `989ad5212971097df868dabab557c1c076d91720`:

| PR | Compare to current main | Updated decision |
|---|---|---|
| #47 | Diverged; 27 commits ahead, 3 behind | Rebase required. Backend CI passed, Flutter run cancelled. Keep separate and do not deploy migration 0003 without explicit approval. |
| #50 | Diverged; 77 ahead, 3 behind; GitHub mergeable=false | Resolve conflicts/rebase before considering merge. |
| #53 | Diverged; 41 ahead, 3 behind | Rebase required even though exact-head CI passed; deployment remains separately gated. |
| #54 | Diverged; 3 ahead, 3 behind; exact-head Flutter run cancelled | Compare its Android storage persistence test with #58 before selecting one or both. |
| #57 | Closed unmerged | Superseded by #60; its workflow improvements are incorporated in the active Phase 0 branch. |
| #58 | 1 commit ahead, not behind | Keep as a focused database close/reopen assertion; its exact-head emulator run failed at runtime after Flutter tests passed. |
| #59 | QA-stack comparison: 78 commits ahead, 3 behind main | Remains based on QA #50; not main-ready. |
| #60 | Active Phase 0 head `d4962ea...` | Main-based; exact-head CI run #45501790768 is the current validation run. |
| #68 | Active Phase 1 head before synchronization `93d3544...` | Now synchronized to #60 head; rerun exact-head CI after the merge commit. |

### Backup PR disposition

- #18 encrypted archive, #19 encrypted archive integration, and #20 Google Drive backup were closed with explicit comments because backup/restore are excluded from AcademicOS. Their branches remain only as Git history and must not be merged.
- #61–#67 were superseded and closed as Phase 1 was iterated. No code was merged from those superseded PRs.
- PR #57 was closed unmerged after all of its useful CI changes were incorporated into #60.
- Current execution PRs: #60 (Phase 0) and #68 (Phase 1, synchronized with and stacked on #60).

The comparison is a point-in-time integration snapshot. Refresh the base/head SHAs and CI before merging either current PR.
