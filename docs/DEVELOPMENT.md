# Development

This guide describes local checks and safety expectations for C Drive Cleaner Skill.

## Repository Shape

- `c-drive-cleaner/SKILL.md` contains the skill instructions.
- `c-drive-cleaner/scripts/c_drive_cleaner.ps1` is the cleanup script.
- `c-drive-cleaner/scripts/project_artifact_inventory.ps1` is a read-only analyzer for reproducible project dependencies and compiler output.
- `c-drive-cleaner/scripts/storage_inventory.ps1` is the read-only comprehensive inventory script.
- `c-drive-cleaner/references/safety.md` documents the safety model.
- `examples/sample-audit-report.json` shows report output.

## PowerShell Syntax Check

Run this from the repository root:

```powershell
$tokens = $null
$errors = $null
Get-ChildItem "c-drive-cleaner/scripts/*.ps1" | ForEach-Object {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $_.FullName,
    [ref]$tokens,
    [ref]$errors
  ) | Out-Null
  if ($errors.Count -gt 0) { $errors | Format-List; exit 1 }
}
```

## Inventory Smoke Check

Scan only the repository directory so CI does not traverse the runner's whole system drive:

```powershell
.\c-drive-cleaner\scripts\storage_inventory.ps1 -RootPath . -MaxDepth 3 -ReportPath .\inventory-smoke.json | Out-Null
$report = Get-Content -Raw .\inventory-smoke.json | ConvertFrom-Json
if ($report.FileCount -lt 1 -or $report.IsWholeDrive) { throw "Inventory smoke check failed" }
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

## Project Artifact Smoke Check

Create a disposable fixture containing one manifest-backed dependency tree, one ambiguous output directory, and one orphan compiler tree. Assert that the analyzer classifies them as `safe_rebuildable`, `review_output`, and `review_missing_manifest` respectively. The analyzer must not delete or modify the fixture.

## Safety Expectations

Changes must preserve:

- Audit-first behavior.
- Explicit clean-mode confirmation.
- Documented allowlist boundaries.
- No automatic deletion of Downloads, Documents, Desktop files, source code, synced folders, arbitrary large files, installed apps, restore points, or `Windows.old`.
- Safe handling for locked files, permission-denied files, and reparse points.
- Bounded reporting for errors and skipped reparse points.
- Separate logical-size inventory from reclaimable-space estimates.
- Actual drive free-space verification after cleanup.
- Ecosystem-specific package-cache approval and ordinary-browser-cache separation from Service Worker/profile data.
- Project artifact discovery remains read-only; deletion requires a fixed literal target list and protected-file verification.
