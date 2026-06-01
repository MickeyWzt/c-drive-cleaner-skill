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
- Optionally inspect browser caches and recycle bin cleanup.
- Produce a JSON report before and after cleanup.
- Keep downloads, documents, projects, synced folders, and app installs out of scope.

## Safety Model

The default behavior is intentionally conservative:

- Audit first, clean second.
- Cleanup requires `-Mode Clean -ConfirmClean`.
- Temp/cache cleanup defaults to files older than 7 days.
- Browser caches are opt-in with `-IncludeBrowserCaches`.
- Recycle bin cleanup is opt-in with `-IncludeRecycleBin`.
- Large-file scanning is advisory only and never deletes personal files.
- Deletion is restricted to an allowlist of temp/cache locations.

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

Run an approved temp-file cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -ReportPath .\c-drive-cleaner-after.json
```

## Example Output

```text
Mode: Audit
Drive: C:
Free: 52.05 GB
Estimated reclaimable: 267.21 MB
Deleted: 0 B
Targets:
  - User temp
  - Windows temp
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

## License

MIT
