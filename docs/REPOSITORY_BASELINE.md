# AcademicOS — Repository Baseline

**Snapshot date:** 2026-11-24 (UTC)  
**Repository:** [EduNivora/AcademicOS](https://github.com/EduNivora/AcademicOS)  
**Default branch:** `main`  
**Baseline SHA:** `989ad5212971097df868dabab557c1c076d91720`  
**Visibility:** public  
**Repository permissions observed:** admin / maintain / push available to the connected GitHub identity.

## Verified repository state

- The live `refs/heads/main` API returned the baseline SHA above. It matches the supplied reference SHA.
- The default branch is `main`; no changes were made directly to it.
- The repository PR inventory endpoint returned 53 PRs: 36 open, 17 closed, 12 merged.
- The branch search returned 60 branch names on its first page and a continuation cursor; therefore this is not a complete branch count.
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

Combined commit statuses returned no legacy status contexts for the seven queried SHAs; Actions run evidence above is the stronger available evidence.

## Working branch created for this baseline

- Branch: `chore/phase0-baseline-ci-hardening`
- Parent: `989ad5212971097df868dabab557c1c076d91720`
- Initial workflow fix commit: `7bbbe93d282566109c2831e31ad2ef71284265a7`
- Follow-up workflow fix commit: `0b1c3c8f1779217a5d85a67e96370f75e37a9a6e`
- Scope: make every Flutter quality workflow pipeline using `tee` fail closed under Bash `set -euo pipefail`, including dependency resolution, tests and build pipelines. Additional tee commands were inspected in their surrounding strict-shell blocks.

## Limits of this snapshot

GitHub API inventory and file reads were available. A local Git clone could not be established in this execution environment because outbound DNS/network access to github.com was unavailable. Consequently, no local Flutter/Dart command is claimed as executed here. CI must validate the new branch before this phase is accepted.
