---
name: c-drive-cleaner
description: Safely inventory, audit, and clean reclaimable Windows system-drive space. Use when Codex is asked to find what is filling C:, perform a comprehensive disk-usage scan, clean Windows or user caches and temporary files, review large files, or prepare and execute a cautious Windows cleanup with before/after verification.
---

# C Drive Cleaner

## Operating Rule

Treat drive cleanup as destructive. Inventory and audit first, name exact categories and recovery costs, then clean only categories the user explicitly approves. Never turn an inventory hotspot into deletion authorization.

## Workflow

1. Confirm Windows and identify the system drive, normally `C:`. Record total, used, free, and free percentage.
2. For “full”, “comprehensive”, “what is taking space”, or unclear low-space requests, run the read-only inventory first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/storage_inventory.ps1 -Drive C: -ReportPath ./c-drive-inventory.json
```

3. Run `c_drive_cleaner.ps1 -Mode Audit` for reclaimable estimates. Use `-Preset Deep` for built-in Windows/browser categories. Add each approved package ecosystem, NVIDIA download, or installer cache only with its explicit switch.
4. Separate findings into: high-confidence rebuildable caches; opt-in data with a recovery/download cost; personal or project files requiring manual review; protected system areas that must use supported Windows tooling.
5. Report inaccessible paths, reparse points, hard-link caveats, locked files, admin requirements, and the exact age threshold. Do not present logical WinSxS size as reclaimable space.
6. Ask for approval naming every category. Run clean mode only with the same reviewed switches plus `-ConfirmClean`. Close relevant apps when practical; skip locked files instead of terminating processes.
7. If project/work directories dominate, read `references/project-artifacts.md` and run the read-only artifact inventory. Never treat a project hotspot as automatic deletion authorization.
8. Re-run the same audit and verify both per-category deletion totals and the drive’s actual free-space delta. Explain that application activity can make those numbers differ.

## Safe Defaults

Use these defaults unless the user requests otherwise:

- Delete only files older than 7 days from temp/cache categories unless the user explicitly approves a different threshold.
- Include user temp and Windows temp in the first cleanup proposal.
- Keep browser caches opt-in with `-IncludeBrowserCaches`. This covers ordinary Cache, Code Cache, and GPUCache only; keep Service Worker storage, cookies, passwords, history, and login data out of scope.
- Keep recycle bin opt-in with `-IncludeRecycleBin`.
- Use `-Preset Deep` for a high-yield audit when the user asks for maximum space, then ask before cleaning.
- Use `-Preset Maximum` only after the user accepts a stronger cleanup that includes DISM component store cleanup.
- Prefer `-IncludePipCache`, `-IncludeNpmCache`, or `-IncludeUvCache` so approval stays ecosystem-specific. `-IncludePackageManagerCaches` is a compatibility alias for all three. Read `references/package-caches.md` before running native cache maintenance. Never delete Conda `pkgs` directly.
- Keep NVIDIA driver/app downloads opt-in with `-IncludeNvidiaDownloadCache` and installer temp opt-in with `-IncludeInstallerTemp`.
- Do not remove downloads, documents, desktop files, OneDrive folders, project folders, source code, package managers, virtual environments, or application install directories automatically.
- Do not use broad commands like `Remove-Item C:\*`, `rd /s C:\...`, `git clean`, or wildcard deletion outside the script's allowlist.

## Script Usage

Use `scripts/c_drive_cleaner.ps1` for deterministic auditing and cleanup.

Comprehensive read-only inventory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/storage_inventory.ps1 -Drive C: -MaxDepth 5 -ReportPath ./c-drive-inventory.json
```

Common audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Audit -MinAgeDays 7 -ReportPath ./c-drive-cleaner-report.json
```

Deep audit for more reclaimable space:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Audit -Preset Deep -MinAgeDays 7 -ReportPath ./c-drive-cleaner-deep-report.json
```

Audit high-yield developer and installer caches without cleaning them:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Audit -IncludeNpmCache -IncludeUvCache -IncludeNvidiaDownloadCache -IncludeInstallerTemp -MinAgeDays 7 -ReportPath ./c-drive-cleaner-extra-report.json
```

Read-only project artifact inventory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/project_artifact_inventory.ps1 -RootPath C:\path\to\projects -MinSizeMB 16 -ReportPath ./project-artifacts.json
```

Approved cleanup of temp files only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -ReportPath ./c-drive-cleaner-after.json
```

Approved cleanup including browser caches:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -IncludeBrowserCaches -ReportPath ./c-drive-cleaner-after.json
```

Maximum cleanup after the user approves the audit categories and DISM component cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/c_drive_cleaner.ps1 -Mode Clean -Preset Maximum -ConfirmClean -MinAgeDays 7 -ReportPath ./c-drive-cleaner-maximum-after.json
```

## Reporting

Report in this shape:

- Current free space and estimated reclaimable space.
- Inventory coverage: logical bytes scanned, inaccessible count/samples, skipped reparse-point count/samples, directory hotspots, and top large files.
- Categories scanned, including age threshold and whether they were cleaned.
- Categories skipped because of permissions, locked files, or missing paths.
- Files the script refused to touch because they were outside the allowlist.
- DISM component cleanup result when `-RunComponentCleanup` or `-Preset Maximum` is used.
- Actual free-space increase, script-counted deleted bytes, and the accounting difference.
- A numbered decision table for remaining app/offline data, model caches, downloads, project artifacts, and uninstall candidates.
- Recommended next step, such as Windows Storage Sense, Disk Cleanup, uninstalling large apps, or manually reviewing large files.

## References

Read `references/safety.md` before adding new cleanup categories or changing deletion behavior.

Read `references/package-caches.md` for ecosystem-native cache maintenance. Read `references/project-artifacts.md` before proposing deletion inside project or Codex work directories.
