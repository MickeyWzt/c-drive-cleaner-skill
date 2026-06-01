---
name: c-drive-cleaner
description: Safely audit and clean reclaimable Windows C drive space. Use when Codex is asked to free space on C:, inspect disk usage, clean Windows/user temporary files, browser caches, recycle bin contents, or prepare a cautious cleanup plan for a Windows machine.
---

# C Drive Cleaner

## Operating Rule

Treat C drive cleanup as potentially destructive. Start with an audit, explain exactly what would be removed, and run cleanup only after the user explicitly approves the specific categories.

## Workflow

1. Confirm the target is Windows and identify the system drive, normally `C:`.
2. Run the bundled audit script first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Audit -ReportPath ./c-drive-cleaner-report.json
```

3. Summarize free space, reclaimable estimates, skipped/error paths, and any category that requires admin rights or closed apps.
4. Ask for approval before deleting anything. Name the categories and age threshold.
5. Run cleanup only with `-Mode Clean -ConfirmClean` and only for approved categories.
6. Re-run audit after cleanup and report the before/after free-space delta.

## Safe Defaults

Use these defaults unless the user requests otherwise:

- Delete only files older than 7 days from temp/cache categories.
- Include user temp and Windows temp in the first cleanup proposal.
- Keep browser caches opt-in with `-IncludeBrowserCaches`.
- Keep recycle bin opt-in with `-IncludeRecycleBin`.
- Do not remove downloads, documents, desktop files, OneDrive folders, project folders, source code, package managers, virtual environments, or application install directories automatically.
- Do not use broad commands like `Remove-Item C:\*`, `rd /s C:\...`, `git clean`, or wildcard deletion outside the script's allowlist.

## Script Usage

Use `scripts/c_drive_cleaner.ps1` for deterministic auditing and cleanup.

Common audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Audit -MinAgeDays 7 -ReportPath ./c-drive-cleaner-report.json
```

Audit including browser caches and large user-file hints:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Audit -IncludeBrowserCaches -ScanLargeFiles -ReportPath ./c-drive-cleaner-report.json
```

Approved cleanup of temp files only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -ReportPath ./c-drive-cleaner-after.json
```

Approved cleanup including browser caches:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -IncludeBrowserCaches -ReportPath ./c-drive-cleaner-after.json
```

## Reporting

Report in this shape:

- Current free space and estimated reclaimable space.
- Categories scanned, including age threshold and whether they were cleaned.
- Categories skipped because of permissions, locked files, or missing paths.
- Files the script refused to touch because they were outside the allowlist.
- Recommended next step, such as Windows Storage Sense, Disk Cleanup, uninstalling large apps, or manually reviewing large files.

## References

Read `references/safety.md` before adding new cleanup categories or changing deletion behavior.
