# EduNivora Release 1 — Track B Execution Status

**Last updated:** 2026-11-17 UTC  \n**Current branch head:** see the live head of [PR #32](https://github.com/EduNivora/AcademicOS/pull/32).  \n**Latest backend code/test head attempted:** `b8eaaa9431c54b22580b8c5a5ef4f4dcbeffdf60` (later commits in this branch are documentation-only).

**Repository:** `EduNivora/AcademicOS`  
**Track B branch:** `release1/backend-platform-completion`  
**PR target:** `chore/edunivora-phase0-execution`  
**Required common baseline:** `8c1902ce3188f4ca74e6813c5174a651ed6d0c97`  
**Release scope:** Android application only

## Status vocabulary

Only these status values are used below: `DONE — VERIFIED`, `IN PROGRESS`, `NOT VERIFIED`, `BLOCKED — EXTERNAL INPUT REQUIRED`, `DEFERRED — RELEASE 2`.

A status is not promoted to verified merely because source exists. CI claims must identify the exact commit and run. Runtime and production deployment claims require live evidence.

## Track B acceptance ledger

| Area | Status | Current evidence and remaining work |
|---|---|---|
| Minimal Neon schema and migrations | IN PROGRESS | Source migrations define only profile projection, notices, registered delivery/read receipts, anonymous aggregate counters, and narrow operator audit. Clean Neon child-branch migration execution and idempotency/rollback evidence must be run on the exact Track B head. No academic data tables are permitted. |
| Neon Managed Auth JWT verification | IN PROGRESS | Source verifies EdDSA signatures using configured JWKS and checks issuer/audience against the Neon auth origin. Exact-head automated tests must pass for missing, invalid, expired, wrong-issuer, wrong-audience and disabled/missing-profile cases. Real-account token lifecycle remains unverified. |
| Email/password and OTP production flow | BLOCKED — EXTERNAL INPUT REQUIRED | Neon Managed Auth source integration exists, but production SMTP is not confirmed. Owner must supply an approved SMTP host, port, sender, username and secret directly through Neon/provider secret settings. Do not send credentials in chat or commit them. |
| Production Google OAuth | BLOCKED — EXTERNAL INPUT REQUIRED | No project-owned Google OAuth client is confirmed. Owner must supply the project-owned client ID/secret and approve exact redirect/trusted-origin configuration. Do not reuse shared development credentials. |
| Public notice API | IN PROGRESS | Source includes public feed/detail, draft creation/edit, publish/archive and protected reports. Exact-head tests must pass; live publication and read/feed runtime behavior are not accepted by source alone. |
| Registered delivery/read receipts | IN PROGRESS | Separate account-linked delivery and read tables/routes exist. Exact-head idempotency, JWT expiry, FK behavior and live authenticated receipt tests remain required. Delivery is not a read. |
| Operator authorization and audit | IN PROGRESS | Every privileged route must resolve the server-owned role projection; client role fields are not trusted. Verify unauthorized, ordinary-user and admin cases, plus atomic audit writes, on the exact head. First-admin bootstrap has not been executed. |
| Anonymous guest metrics Worker and Durable Object | IN PROGRESS | Source implements per-notice/per-UTC-day atomic quotas, published-notice validation, aggregate-only Durable Object storage, minimal upstream headers and fail-closed secret checks. Node and Cloudflare runtime/concurrency suites must pass on this exact head. |
| Guest metrics production protection | BLOCKED — EXTERNAL INPUT REQUIRED | No Worker deployment or matching production secret provisioning is authorized by this order. Requires explicit owner approval and one random secret (at least 32 bytes) installed as Worker `NEON_GUEST_METRICS_SECRET` and Neon `GUEST_METRICS_PROXY_SECRET`. Deployment and smoke-test procedure is documented. |
| Neon Function production deployment | BLOCKED — EXTERNAL INPUT REQUIRED | Existing deployment 7 predates the current reviewed source and does not establish current JWT/guest-metric enforcement. A reviewed bundle, owner approval, verified environment values, deployment and live smoke tests are required. No deployment is performed here. |
| Exact-head GitHub Actions runner execution | BLOCKED — EXTERNAL INPUT REQUIRED | Backend code checks on `b8eaaa9431c54b22580b8c5a5ef4f4dcbeffdf60` and the later documentation head `cde962f5f0dbdcdf9a05b7212fd14e7a2eea3382` were created but failed before runner allocation. Latest backend/Worker runs on `cde962f5f0dbdcdf9a05b7212fd14e7a2eea3382`: Neon #44051636833 and Worker #44051636561. Latest Android run #44051734423 ran on `113d8a4b391c5a8d2c7d3a461d6d4109ec5da5a6`. Each job reports `runner_id: 0`, zero steps, and no job log. No install, test, Wrangler, Flutter, or APK command ran. Owner must restore GitHub Actions runner/billing availability and rerun checks on the live PR head. |
| Worker Durable Object quality gate | BLOCKED — EXTERNAL INPUT REQUIRED | The workflow includes Node tests, Wrangler dry-run and Cloudflare Vitest runtime tests, but exact-head execution is blocked before runner allocation; no test command ran. |
| Flutter Android quality workflow | BLOCKED — EXTERNAL INPUT REQUIRED | Workflow is configured for dependency resolution, Dart formatting/analyzer, Flutter tests, Android Debug APK, Android Release QA APK, and separate artifact uploads. Release QA APK uses debug signing and is not production-signed. Exact-head execution is blocked before runner allocation. |
| Production Android signing | BLOCKED — EXTERNAL INPUT REQUIRED | Requires project-owned keystore, store password, key alias and key password provisioned as protected GitHub secrets, plus owner approval. No fake signing credentials or keystore are created. |
| Physical Android installation/runtime acceptance | NOT VERIFIED | Requires installation and smoke testing on a real Android device or approved emulator. CI APK compilation is not device acceptance. Track A owns application-source acceptance. |
| Web app, Web admin, browser persistence and Cloudflare Pages | DEFERRED — RELEASE 2 | No Web application, Web admin, browser persistence, Web artifact or Pages deployment is a Release 1 acceptance requirement. Do not add Pages origins or activate Web deployment. |
| Google Drive backup/restore, backup encryption/key management, production SQLite encryption, academic cloud sync | DEFERRED — RELEASE 2 | These are explicitly excluded. No academic payload or attachment bytes may be added to Neon. |
| Track A Flutter source and acceptance | NOT VERIFIED | Track B does not modify `lib/**`, `android/**`, `test/**`, `integration_test/**`, Flutter assets, `pubspec.yaml`, or `pubspec.lock`. Do not mark Track A items complete without its exact commit and exact-head CI evidence. |

## Exact-head CI evidence

- [Neon backend run #44051636833](https://github.com/EduNivora/AcademicOS/actions/runs/44051636833) on code-equivalent docs head `cde962f5f0dbdcdf9a05b7212fd14e7a2eea3382` — failed before runner allocation; zero steps.
- [Guest metrics Worker run #44051636561](https://github.com/EduNivora/AcademicOS/actions/runs/44051636561) on the same SHA — failed before runner allocation; zero steps.
- [Flutter/Android run #44051734423](https://github.com/EduNivora/AcademicOS/actions/runs/44051734423) on `113d8a4b391c5a8d2c7d3a461d6d4109ec5da5a6` — failed before runner allocation; zero steps.
- Earlier code-head runs on `b8eaaa9431c54b22580b8c5a5ef4f4dcbeffdf60`: [Neon #44049534380](https://github.com/EduNivora/AcademicOS/actions/runs/44049534380), [bundle #44049534368](https://github.com/EduNivora/AcademicOS/actions/runs/44049534368), [Worker #44049534484](https://github.com/EduNivora/AcademicOS/actions/runs/44049534484), and [Flutter #44049534386](https://github.com/EduNivora/AcademicOS/actions/runs/44049534386) — all failed before runner allocation; zero steps.

These are not code-test failures and are not passing checks. No install, test, Wrangler, Flutter, or APK command ran. Resolve runner availability and rerun checks on the live PR head.

## Production safety boundary

No production Neon Function, Cloudflare Worker, Neon secret, Cloudflare secret, SMTP provider, OAuth provider, trusted origin, or administrator account is changed by this branch. Source/CI verification is not runtime verification and is not production deployment.

## Historical evidence (not evidence for this Track B head)

- Integration commit `1f9af129a17130000a79c045f343f96c3bdeff4b` had Neon backend quality run [#43898756983](https://github.com/EduNivora/AcademicOS/actions/runs/43898756983) succeed. This historical run predates the Track B branch and does not verify the new Worker or workflow changes.
- PR #27 is a Draft source reference for the anonymous quota Worker. Its head and CI evidence must be rechecked; no historical PR run is substituted for the exact Track B commit.
- PR #28 is a Draft Android Release-variant workflow reference. Its changes are incorporated only within the Track B-owned workflow file and must be revalidated on the exact Track B commit.

## Release decision

**NOT READY — Track B exact-head CI, clean migration validation, live authenticated API acceptance, production secret provisioning/deployment approval, and Track A Android runtime acceptance remain outstanding.**
