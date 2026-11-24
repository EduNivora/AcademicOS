# AcademicOS — PR Integration Map

**Baseline:** `main@989ad5212971097df868dabab557c1c076d91720`  
**Snapshot:** 2026-11-24

## Integration dependencies and overlaps

| PR | Base → head | Shared files / dependency | Decision |
|---|---|---|---|
| #47 Gemini quotas | main → `feat/ai-durable-account-quotas` | Neon backend workflow, package scripts, Neon README and AI function | Keep isolated. Requires migration review and fresh Flutter CI; do not deploy. |
| #50 QA candidate | main → `qa/uiux-release-candidate` | Flutter workflow, DB helper/schema tests, assistant executor/screen and UI | Conflict reported by GitHub (mergeable=false). Resolve/rebase before acceptance. |
| #53 guest metrics | main → `feat/guest-metrics-edge-gateway-mainline` | Flutter + Neon workflows and Neon notices backend | CI passed on exact head, but deployment prerequisites remain. Its workflow overlaps #57 and #50. |
| #57 Flutter pipefail | main → `fix/main-flutter-test-pipefail` | Only `.github/workflows/flutter-quality.yml`; same file as #50/#53 | Correct narrow fix; full run blocked by emulator instability. New baseline PR generalizes strict pipefail to all tee pipelines and incorporates #57's 4-core/4-GB emulator sizing plus Package Manager readiness probe. PR #57 is therefore superseded in source scope; do not merge competing workflow snapshots. |
| #58 attachment reopen test | main → `test/attachment-close-reopen-mainline` | `test/database_schema_test.dart`; same test file also touched by QA/attachment work | Keep separate and revalidate; do not infer BLOB architecture approval from this test. |
| #59 assistant postconditions | QA #50 → `feat/assistant-postcondition-verification-qa-rebased` | Assistant executor, assistant screen, schedule screen, acceptance docs | Stacked on QA, not main. Integrate only after #50 base is resolved and the stack is deliberately replayed/rebased. |
| #52 assistant postconditions (older) | QA → `feat/assistant-postcondition-verification` | Same assistant executor/screen as #59 | Superseded by rebased #59 candidate; do not merge both. |
| #54 attachment persistence proof | main → `test/durable-course-attachment-persistence` | Android integration test and attachment BLOB path | Compare with #58 before integrating; avoid duplicate test assertions. |
| #55 assistant postconditions (older) | QA → `feat/assistant-postcondition-verification-current-qa` | Same assistant files as #59 | Closed unmerged; historical source only. #59 is the current rebased candidate. |
| #56 QA pipefail | QA → `fix/qa-flutter-test-pipefail` | Flutter workflow | Merged into QA only; not main. Do not treat as mainline fix. |
| #17 attachment storage | historical phase0 branch → durable attachment branch | DB helper, BLOB persistence, backup serialization | Already merged into the phase0 integration line; BLOB implementation is current persistence evidence, not a final architecture decision. |
| #18–#20 backup archive / Drive | phase0 / encrypted archive stack | Backup archive, crypto and Drive integration | Open Release 2 work; excluded from current Release 1 scope. Do not merge. |
| #13 attachment path guard | phase0 integration line | Material path and PDF viewer | Historical mitigation. Its stale base and backup-era references must not be pulled into the current mainline without re-review. |

## Suggested integration order

1. Merge this Phase 0 CI/documentation PR only after its exact-head Flutter quality run passes.
2. Re-run #57 or supersede it with the strict-shell implementation from this PR; do not merge two competing workflow snapshots.
3. Resolve #50 against current main and rerun its complete quality gate; only then consider #59 and its assistant-stack dependencies.
4. Review #58 and #54 together for duplicate coverage; merge only the minimal proven test set.
5. Keep #47 and #53 separate from Flutter UI stacks. Their backend CI does not authorize migrations, secrets, or deployment.
6. Keep #18–#20 closed out of the Release 1 integration path; remove in-app backup/restore code through the separate Phase 1 PR while retaining academic reports.

## Repository-wide inventory

The repository API snapshot contained 53 PRs (36 open, 17 closed, 12 merged). The active PRs and branches that directly affect the current integration sequence are enumerated above. The remaining active PRs are separate release, authentication, web-runtime, database, UI, and historical phase0 stacks; their base branches are not interchangeable with main. Do not mass-merge them as a batch.
