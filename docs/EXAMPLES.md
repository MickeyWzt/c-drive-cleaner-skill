# Examples

These examples show safe cleanup workflows. Start with audit-only commands and review the report before approving any cleanup.

## Example 1: Basic Audit

Use this as the first command on a new machine.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -ReportPath .\c-drive-cleaner-report.json
```

Expected result: a JSON report showing detected cleanup targets and estimated reclaimable space. No files are deleted.

## Example 2: Deep Audit

Use this when the standard audit does not find enough reclaimable space.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -Preset Deep -ReportPath .\c-drive-cleaner-deep-report.json
```

Review the report carefully. Deep mode includes more cache categories, but it still avoids personal folders by design.

## Example 3: Approved Temp Cleanup

Run this only after reviewing an audit report.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -ReportPath .\c-drive-cleaner-after.json
```

The `-ConfirmClean` flag is intentional. It makes cleanup an explicit user decision.

## Example 4: Maximum Audit Before a Strong Cleanup

Use this when a drive is very full and you need to inspect the strongest built-in path.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -Preset Maximum -ReportPath .\c-drive-cleaner-maximum-report.json
```

If the report looks acceptable, run the clean command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -Preset Maximum -ConfirmClean -MinAgeDays 7 -ReportPath .\c-drive-cleaner-maximum-after.json
```

## Example 5: Report a Cleanup Bug

Include:

- Windows version.
- PowerShell version.
- Full command line.
- Preset and mode.
- Audit report excerpt with private paths removed.
- Error messages.
- Whether the command was audit-only or clean mode.
