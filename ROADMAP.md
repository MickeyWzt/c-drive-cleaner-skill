# Roadmap

This roadmap keeps the project focused on cautious Windows cleanup. New behavior should make audits clearer or cleanup safer.

## Current Focus

- Preserve audit-first behavior.
- Keep destructive actions behind explicit confirmation.
- Maintain strict allowlist boundaries.
- Make JSON reports useful before and after cleanup.

## Near-Term Improvements

- Add tests for path allowlist rules.
- Add tests for reparse point handling.
- Improve report summaries for skipped, locked, and permission-denied files.
- Add more examples of `Standard`, `Deep`, and `Maximum` audit reports.
- Improve documentation for Windows cleanup categories.

## Longer-Term Ideas

- Optional HTML report rendering.
- More cache categories after safety review.
- Better summary of advisory large-file findings.
- Safer dry-run estimates for package-manager caches.
- CI checks for PowerShell syntax and safety rules.

## Non-Goals

- Deleting personal folders automatically.
- Deleting arbitrary large files.
- Bypassing permissions or forcing locked-file deletion.
- Hiding destructive behavior behind defaults.
