# AcademicOS — Repository Baseline

**Snapshot date:** 2026-11-26 (UTC)  
**Repository:** [EduNivora/AcademicOS](https://github.com/EduNivora/AcademicOS)  
**Default branch:** `main`  
**Baseline SHA:** `9df489c0f8c1d960cae337033717fc27a78ff4ec`  
**Visibility:** public  
**Repository permissions observed:** admin / maintain / push available to the connected GitHub identity.

## Verified repository state

- The live `refs/heads/main` API returned `a84d62016ec1c3d2febe9e054f2c43b335d1cba4`. The pre-Phase-0 historical baseline was `989ad5212971097df868dabab557c1c076d91720`.
- The default branch is `main`; no changes were made directly to it.
- The repository PR inventory endpoint returned 53 PRs: 36 open, 17 closed, 12 merged.
- At the initial baseline snapshot, branch search returned 60 names on its first page and a continuation cursor. A later full branches API snapshot is recorded below.
- Mainline Flutter quality run [#45433357599](https://github.com/EduNivora/AcademicOS/actions/runs/45433357599) completed successfully on the exact baseline SHA. It covered dependency resolution, Dart analysis, Flutter tests, Android emulator SQLite integration, Android Debug APK and Web Release build. It did not produce a signed production ARM64 APK.

## Exact-head PR evidence

| PR | Head SHA | Base | Exact-head CI evidence | Integration assessment |
|---|---|---|---|---|
| [#47](https://github.com/EduNivora/AcademicOS/pull/47) | `ec52bd9d4cd8d96958729963b27774c9d8ed0de3` | main at `50dc34a...` | Backend run #44909953287 passed; Flutter run #44909953393 cancelled during Android emulator verification | Draft; backend-only success is insufficient. Migration 0003 requires review; do not deploy or merge without a fresh full gate. |
| [#50](https://github.com/EduNivora/AcademicOS/pull/50) | `b0faf98777d482baf01cee18df198611ebe420e5` | main at `50dc34a...` | No PR-triggered run found for this SHA in the queried run collection | Draft; GitHub reports mergeable=false. Do not merge before resolving the conflict and rerunning CI. |
| [#53](https://github.com/EduNivora/AcademicOS/pull/53) | `2f1589113c74f0a4bc76642ac8593483d7428f44` | main at `50dc34a...` | Backend #45271485684 and Flutter #45271485543 succeeded | Draft; deployment and secret-coordination gates remain separate. Shares Flutter and Neon workflow/backend files with other PRs. |
| [#57](https://github.com/EduNivora/AcademicOS/pull/57) | `2ce5e1c9c52745de79fba281fc9e4d9e8d2882ac` | main at baseline SHA | Analysis and Flutter tests passed; Android emulator step failed | Focused CI fix. Emulator log shows app install followed by “Error waiting for a debug connection: The log reader stopped unexpectedly”; no Flutter test failure. Keep unmerged until a fresh full CI run succeeds. |
| [#58](https://github.com/EduNivora/AcademicOS/pull/58) | `877e7c637c263c0c3eedfd984aa26e8d260f8faf` | main at baseline SHA | Analysis and Flutter tests passed; emulator process/system_server crashed during integration | Focused DB close/reopen regression test. Failure is emulator/runtime instability in this run, not evidence that the Flutter test suite failed. Require fresh exact-head CI. |
| [#59](https://github.com/EduNivora/AcademicOS/pull/59) | `d6759a347c731b624c0b0d3931fb07bafeb3f1ae` | QA branch at `b0faf987...` | Flutter and assistant safety workflows succeeded | Stacked on #50/QA, not main. Its green CI does not establish main readiness. |
| [#60](https://github.com/EduNivora/AcademicOS/pull/60) | `d4962ea5f0bb803f5a67d9a08cfeef60c07a1134` | main at historical baseline | Flutter quality run [#45501790768](https://github.com/EduNivora/AcademicOS/actions/runs/45501790768) succeeded; merged as `a84d620...` with the same tree | Merged; Phase 0 baseline and workflow hardening are now in main. |
| [#68](https://github.com/EduNivora/AcademicOS/pull/68) | `999dd635ebaa5ed362efb02a84e60ec5354141ac` | main at `a84d620...` | Exact-head Flutter quality run [#45531164225](https://github.com/EduNivora/AcademicOS/actions/runs/45531164225) succeeded: 155 tests, 0 analyzer errors/warnings, Android SQLite integration and Android/Web builds | Merged into `main` as `9df489c0f8c1d960cae337033717fc27a78ff4ec`; exact-head CI succeeded. |

Combined commit statuses returned no legacy status contexts for the seven queried SHAs; Actions run evidence above is the stronger available evidence.

## Working branch created for this baseline

- Branch: `chore/phase0-baseline-ci-hardening`
- Parent: `989ad5212971097df868dabab557c1c076d91720`
- Initial workflow fix commit: `7bbbe93d282566109c2831e31ad2ef71284265a7`
- Follow-up workflow fix commit: `0b1c3c8f1779217a5d85a67e96370f75e37a9a6e`
- Scope: make every Flutter quality workflow pipeline using `tee` fail closed under Bash `set -euo pipefail`, including dependency resolution, tests and build pipelines. Additional tee commands were inspected in their surrounding strict-shell blocks.

## Limits of this snapshot

GitHub API inventory and file reads were available. A local Git clone could not be established in this execution environment because outbound DNS/network access to github.com was unavailable. Consequently, no local Flutter/Dart command is claimed as executed here. CI must validate the new branch before this phase is accepted.


## Execution update — current GitHub state

**Verified after PR creation and backup PR closure (2026-11-24):**

- `main` remains unchanged at `989ad5212971097df868dabab557c1c076d91720`.
- GitHub returned 62 pull requests: 34 open, 28 closed, 12 merged.
- GitHub returned 69 branch refs. This includes the active Phase 0 and Phase 1 branches and seven superseded Phase 1 branches retained for audit traceability.
- Latest commit timestamps for the main integration branches (UTC): `main` 2026-11-24 16:07; #47 2026-11-21 13:39; #50 2026-11-24 16:58; #53 2026-11-23 21:36; #58 2026-11-24 16:54; #59 2026-11-24 17:02; Phase 0 #60 2026-11-24 22:31. The active Phase 1 branch was last updated 2026-11-24 22:33 before synchronization with Phase 0.
- PR #60 is the active Phase 0 PR: `chore/phase0-baseline-ci-hardening` at `d4962ea5f0bb803f5a67d9a08cfeef60c07a1134`, based directly on the baseline `main` SHA.
- PR #68 is the active Phase 1 PR: `feat/phase1-remove-backup-separate-reports-v8`, synchronized with Phase 0 head `d4962ea5f0bb803f5a67d9a08cfeef60c07a1134` by a two-parent merge commit. The current head SHA is authoritative in GitHub.
- PR #57 was closed as superseded by PR #60 after its emulator sizing and Package Manager readiness changes were incorporated.
- PRs #61–#67 were superseded Phase 1 attempts and closed without merging. PRs #18–#20 were closed because backup/restore is excluded from AcademicOS.
- No PR was merged and no production branch, database, secret or user data was changed.

The PR inventory and branch count above are a current execution snapshot; refresh them again before merging.


## Current execution update — 2026-11-25

- Current `main` is `a84d62016ec1c3d2febe9e054f2c43b335d1cba4`, the merge commit for PR #60. Its tree is identical to the Phase 0 head `d4962ea5f0bb803f5a67d9a08cfeef60c07a1134`, whose Flutter quality run #45501790768 succeeded.
- PR #68 targets `main` directly. Its source head `999dd635ebaa5ed362efb02a84e60ec5354141ac` passed Flutter quality run #45531164225: 155 Flutter tests, Dart analyzer 0 errors/0 warnings/42 infos, Android SQLite integration, Android Debug APK/package verification and Web Release build.
- The Phase 1 branch ancestry was synchronized with current main using a tree-preserving merge commit. A subsequent documentation-only update records the current acceptance evidence and must pass a new exact-head run before merge.
- No production deployment, Neon/database migration, secret change or user-data mutation was performed.
- Production-signed ARM64 APK generation remains unverified because signing configuration was not available; WebAssembly dry-run compatibility warnings are documented separately.


## Current execution state — 2026-11-26

- `main` now points to `9df489c0f8c1d960cae337033717fc27a78ff4ec`, the merge commit for PR #68. PR #60 Phase 0 remains included in the mainline ancestry.
- PR #68 Phase 1 passed exact-head run [#45531164225](https://github.com/EduNivora/AcademicOS/actions/runs/45531164225): 155 Flutter tests, analyzer 0 errors/0 warnings/43 infos, Android native SQLite integration, Android Debug APK/package verification and Web Release build. Optional signed ARM64 output was skipped because signing configuration was unavailable.
- PR #69 Phase 3 and PR #70 Phase 4 remain open and stacked. The Flutter Android integration job needs a fresh exact-head run after replacing the flaky Flutter Driver teardown with `flutter test` on the device. PR #70 Neon backend quality passed on its recorded head.
- No production deployment, Neon migration, secret change or user-data mutation is included in this synchronization.
