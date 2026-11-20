# AcademicOS communications readiness

## Current implementation

- The student-facing contact screen validates bug reports and feature requests.
- It can prepare an email draft or copy a structured report to the clipboard; it does not claim to submit messages to a server.
- Official support channels remain marked as pending until the project owners approve and configure them.
- The announcements feed reads published cloud announcements.
- The admin announcements screen provides role-protected announcement management.
- Student reminders and announcements now share one Communications screen with two tabs.

## Safety and product boundaries

- Do not show unapproved email addresses, social accounts, or support channels as official.
- Do not display a "sent" state unless a backend confirms message receipt.
- Keep student contact submissions separate from public announcements and local reminders.
- Preserve the current local email-draft and clipboard paths until a supported support-ticket backend is approved.

## Decisions required before expanding the module

The project owners still need to define the future communication workflow: intended participants, supported message types, whether attachments are allowed, expected response tracking, and which channels are officially approved. Until those requirements are approved, keep the existing contact workflow functional and avoid adding speculative messaging features.
