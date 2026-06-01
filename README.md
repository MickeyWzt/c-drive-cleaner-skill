# C Drive Cleaner Skill

[![GitHub stars](https://img.shields.io/github/stars/MickeyWzt/c-drive-cleaner-skill?style=social)](https://github.com/MickeyWzt/c-drive-cleaner-skill/stargazers)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A safety-first Codex skill for auditing and cleaning reclaimable space on a Windows `C:` drive.

It is built for the boring but important version of disk cleanup: scan first, show exactly what is reclaimable, require explicit approval, and avoid personal files.

If this helped you avoid an unsafe cleanup command, please consider starring the repo so other Windows + Codex users can find it.

## Why Use This

Windows cleanup requests can get dangerous quickly. This skill gives Codex a cautious workflow and a deterministic PowerShell script instead of improvising deletion commands.

Use it when you want to:

- Audit reclaimable space on `C:`.
- Clean user temp and Windows temp files with an age threshold.
- Use deeper opt-in cleanup presets for browser caches, recycle bin contents, Windows update caches, delivery optimization caches, error reports, thumbnails, shader caches, and diagnostic dumps.
- Run Windows component store cleanup through DISM when explicitly requested.
- Produce a JSON report before and after cleanup.
- Keep downloads, documents, projects, synced folders, and app installs out of scope.

## Safety Model

The default behavior is intentionally conservative:

- Audit first, clean second.
- Cleanup requires `-Mode Clean -ConfirmClean`.
- Temp/cache cleanup defaults to files older than 7 days.
- Browser caches are opt-in with `-IncludeBrowserCaches`.
- Recycle bin cleanup is opt-in with `-IncludeRecycleBin`.
- Deep cleanup is opt-in with `-Preset Deep`.
- Maximum cleanup is opt-in with `-Preset Maximum` and adds DISM component cleanup.
- Large-file scanning is advisory only and never deletes personal files.
- Deletion is restricted to an allowlist of temp/cache locations.

## Cleanup Presets

| Preset | What it includes | Best for |
| --- | --- | --- |
| `Standard` | User temp and `C:\Windows\Temp` | Safe first pass |
| `Deep` | Standard plus browser caches, recycle bin, Windows Update download cache, Delivery Optimization cache, Windows Error Reporting, Explorer thumbnail/icon cache, DirectX/NVIDIA shader caches, diagnostic dumps, and large-file hints | Finding more reclaimable space while staying allowlist-based |
| `Maximum` | Deep plus `dism.exe /Online /Cleanup-Image /StartComponentCleanup` in clean mode | The strongest built-in cleanup path after reviewing the audit |

The script still does not automatically delete Downloads, Documents, Desktop files, source code, synced folders, installed applications, package-manager caches, restore points, or `Windows.old`.

## Contents

```text
c-drive-cleaner/
  SKILL.md
  agents/openai.yaml
  references/safety.md
  scripts/c_drive_cleaner.ps1
```

## Quick Start

Run an audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -ReportPath .\c-drive-cleaner-report.json
```

Audit with browser caches included:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -IncludeBrowserCaches -ReportPath .\c-drive-cleaner-report.json
```

Run a deeper audit for more reclaimable space:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -Preset Deep -ReportPath .\c-drive-cleaner-deep-report.json
```

Run an approved temp-file cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -ReportPath .\c-drive-cleaner-after.json
```

Run the strongest built-in cleanup after reviewing a maximum audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Audit -Preset Maximum -ReportPath .\c-drive-cleaner-maximum-report.json
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -Preset Maximum -ConfirmClean -MinAgeDays 7 -ReportPath .\c-drive-cleaner-maximum-after.json
```

## Example Output

See [examples/sample-audit-report.json](examples/sample-audit-report.json) for a fuller sample report.

```text
Mode: Audit
Preset: Deep
Drive: C:
Free: 52.05 GB
Estimated reclaimable: 267.21 MB
Deleted: 0 B
Targets:
  - User temp
  - Windows temp
  - Windows Update download cache
  - Explorer thumbnail cache
  - Diagnostic crash dumps
```

The script skips locked or permission-denied files and records them in the report instead of forcing deletion.

## Install as a Local Codex Skill

Copy the `c-drive-cleaner` folder into your Codex skills directory:

```powershell
Copy-Item -Recurse .\c-drive-cleaner "$env:USERPROFILE\.codex\skills\c-drive-cleaner"
```

Then invoke it in Codex with:

```text
Use $c-drive-cleaner to audit my Windows C drive and prepare a safe cleanup plan.
```

## Repository Link

```text
https://github.com/MickeyWzt/c-drive-cleaner-skill
```

## Contributing

Useful contributions:

- Add more safe cache categories with clear allowlist boundaries.
- Improve report formatting.
- Add tests for path safety rules.
- Document Windows cleanup edge cases.

Before expanding cleanup behavior, read `c-drive-cleaner/references/safety.md`.

For bugs, edge cases, or cache categories that should be reviewed, open a feedback issue using the repository issue template.

## Security

This project is designed around cautious deletion. If you find a path-safety bug or any behavior that may delete data outside the documented allowlist, please report it privately first. See [SECURITY.md](SECURITY.md).

## License

MIT
