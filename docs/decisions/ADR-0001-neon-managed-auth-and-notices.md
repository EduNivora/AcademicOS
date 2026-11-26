# ADR-0001: Neon Managed Auth and PostgreSQL for Release 1 cloud metadata

- Status: Accepted for implementation
- Date: 2026-11-15
- Scope: EduNivora Release 1 account identity and public notices only

## Context

EduNivora is guest-first, local-first, and offline-first. Academic records and
files belong to the student and remain in local SQLite. Release 1 needs a small
shared service for optional accounts, public announcements, registered delivery
and read receipts, and anonymous guest aggregate counters.

## Decision

Use the newly created Neon project `edunivora` (PostgreSQL 17, AWS
`aws-eu-central-1`) as the only cloud relational database for this scope.

Use Neon Managed Auth (Better Auth) for identity, password handling, email
verification, Google OAuth, and session lifecycle. Do not store password hashes
or OAuth tokens in the app-owned tables.

Use a Neon Function named `notices` as the intended API runtime, with Hono,
PostgreSQL `pg` pool, and JWT verification against the branch's Neon Auth JWKS.
The API owns authorization; the Flutter client never receives database
credentials.

The app-owned schema is limited to user profile/role projection, announcements,
registered delivery/read receipts, anonymous daily guest counters, and admin
audit records. No academic data or files may be written there.

## Consequences and open gates

- Guest academic CRUD remains fully usable without account or network.
- Email/password verification is configured with OTP. Production email requires
  a custom SMTP sender and deliverability testing.
- Google OAuth is currently on Neon's shared development provider; production
  requires the project's own Google OAuth client credentials and redirect
  validation.
- Flutter's existing local auth code has not yet been replaced or bridged to
  Managed Auth. The SDK and platform support must be validated before integration.
- The first administrator must be promoted through a controlled operator
  procedure after the account exists; no public admin bootstrap endpoint exists.
- Guest metrics count events, not unique guests. No stable guest identifier is
  retained.
- A retention period and automated purge policy for receipts/audit records must
  be approved before production acceptance.
- The Neon Function is deployed to the default branch and its health route,
  public feed, and unauthenticated admin guard have passed live smoke tests.
  Authenticated JWT flows and end-to-end Flutter behavior remain unverified.
- Backup and restore are excluded from AcademicOS and are not part of this decision.
