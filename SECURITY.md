# Security Policy

## Supported Scope

This repository contains a Codex skill and a PowerShell cleanup helper for Windows C drive audits. Security-sensitive behavior is limited to path selection, deletion boundaries, cleanup confirmation, Windows cleanup command invocation, and report output.

## Reporting a Vulnerability

Please report privately if you find any behavior that could:

- Delete files outside the documented temp/cache allowlist.
- Follow links or resolved paths into personal, synced, or project directories.
- Run cleanup without explicit confirmation.
- Follow reparse points or resolved paths outside the selected cleanup category.
- Run DISM component cleanup outside `-Preset Maximum` or `-RunComponentCleanup`.
- Hide deletion failures or skipped paths from the report.

If the issue is low risk, open a GitHub issue with reproduction steps. If it could cause data loss, contact the maintainer privately before publishing details.

## Safety Expectations

The script should:

- Run in audit mode by default.
- Require `-ConfirmClean` for cleanup.
- Skip inaccessible or locked files instead of forcing deletion.
- Skip reparse points while scanning cleanup directories.
- Keep large-file scans advisory only.
- Avoid Downloads, Documents, Desktop, synced folders, source code, and application install directories.
