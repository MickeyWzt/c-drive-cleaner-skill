# Development

This guide describes local checks and safety expectations for C Drive Cleaner Skill.

## Repository Shape

- `c-drive-cleaner/SKILL.md` contains the skill instructions.
- `c-drive-cleaner/scripts/c_drive_cleaner.ps1` is the cleanup script.
- `c-drive-cleaner/references/safety.md` documents the safety model.
- `examples/sample-audit-report.json` shows report output.

## PowerShell Syntax Check

Run this from the repository root:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "c-drive-cleaner/scripts/c_drive_cleaner.ps1",
  [ref]$tokens,
  [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { $errors | Format-List; exit 1 }
```

## Audit-First Manual Check

Run audit mode before any clean-mode test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -ReportPath .\c-drive-cleaner-report.json
```

Only run clean mode after reviewing the report and confirming the target scope:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -ReportPath .\c-drive-cleaner-after.json
```

## Safety Expectations

Changes must preserve:

- Audit-first behavior.
- Explicit clean-mode confirmation.
- Documented allowlist boundaries.
- No automatic deletion of Downloads, Documents, Desktop files, source code, synced folders, arbitrary large files, installed apps, restore points, or `Windows.old`.
- Safe handling for locked files, permission-denied files, and reparse points.
