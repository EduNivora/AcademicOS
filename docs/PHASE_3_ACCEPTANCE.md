# Phase 3 — Document System Acceptance

Target branch: feat/phase3-document-viewer-rearchitecture  
Base: Phase 1 branch feat/phase1-remove-backup-separate-reports-v8  
Release scope: local attachments only; no backup/restore and no cloud document upload.

## Acceptance matrix

| Requirement | Implementation evidence | Verification |
|---|---|---|
| PDF opens inside AcademicOS | DocumentViewerScreen uses pdfx and a private app-cache file | Android integration test + emulator CI |
| Page navigation and page count | DocumentViewerControls, PdfControllerPinch | Widget tests + Android integration |
| Zoom in/out and pinch zoom | Bounded controller scale and PdfViewPinch | Widget callbacks + physical-device acceptance |
| Large-file behavior | Metadata-only list queries; 50 MiB limit; native file-path rendering | Unit tests + Android emulator; physical-device profiling remains required |
| Loading/error states | Viewer loading overlay and error state | Android integration; widget controls |
| Resource disposal | Close PdfDocument, then delete viewer-owned temp file | Android integration |
| Office files external | open_filex with app-private cache and platform intent | Service unit tests + Android intent integration |
| Missing external app | Typed noAppToOpen result and clear Arabic message | Service unit test; emulator result |
| Safe file path | Generated cache filename; no untrusted path passed to the opener | Unit tests |
| Lazy attachment reads | Metadata queries omit file_bytes; dedicated BLOB read by ID | Database test |
| Local PDF summary | Separate extractor and local summarizer; explicit user action | Unit tests + Android extraction integration |
| Scanned PDF behavior | Empty extracted text maps to noExtractableText; no OCR claim | Unit tests |
| No external document transmission | Summary pipeline has no network dependency | Code review and dependency inspection |

## Implemented in this branch

- Replaced the all-format viewer dependency with a focused PDF renderer and platform Office handoff.
- Moved attachment BLOB retrieval out of course-material list queries.
- Added an app-private temporary-file service with strict extension allowlists and bounded size checks.
- Separated PDF text extraction and local summary generation from the viewer.
- Added unit, widget, database, and Android integration coverage.
- Extended the existing Android emulator quality gate to run both SQLite and document integration tests.

## Verification status

The branch is not accepted until the exact-head CI run passes:
- dependency resolution and lockfile consistency;
- Dart formatting and analysis;
- full Flutter test suite;
- native Android SQLite integration;
- native PDF viewer/text extraction and Office intent integration;
- Android debug APK and Web release builds.

Local Flutter/Dart commands are not claimed as executed by this remote GitHub-only workflow. Physical-device performance, a device with no Office app, and a real third-party Office app handoff remain device acceptance checks.

## Explicit non-goals

- In-app DOC/DOCX/PPT/PPTX rendering.
- OCR for scanned PDFs.
- Sending user documents or extracted text to Gemini or another external service.
- Any backup, restore, cloud sync, or production data migration.
