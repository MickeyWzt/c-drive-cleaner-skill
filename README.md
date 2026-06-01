# C Drive Cleaner Skill

A Codex skill for safely auditing and cleaning reclaimable space on a Windows C drive.

The skill is intentionally conservative:

- Audit first, clean second.
- Cleanup requires explicit approval and the script's `-ConfirmClean` flag.
- Temp and cache cleanup uses an age threshold, defaulting to files older than 7 days.
- Browser caches and recycle bin cleanup are opt-in.
- Large-file scanning is advisory only and never deletes personal files.

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

Run an approved temp-file cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -MinAgeDays 7 -ReportPath .\c-drive-cleaner-after.json
```

Include browser caches only when browsers can be closed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\c-drive-cleaner\scripts\c_drive_cleaner.ps1 -Mode Clean -ConfirmClean -IncludeBrowserCaches -MinAgeDays 7
```

## Install as a Local Codex Skill

Copy the `c-drive-cleaner` folder into your Codex skills directory:

```powershell
Copy-Item -Recurse .\c-drive-cleaner "$env:USERPROFILE\.codex\skills\c-drive-cleaner"
```

Then invoke it in Codex with:

```text
Use $c-drive-cleaner to audit my Windows C drive and prepare a safe cleanup plan.
```

## Safety

Read `c-drive-cleaner/references/safety.md` before expanding cleanup categories. The script refuses paths outside the target drive and deletes only inside an allowlist of temp/cache locations.

## License

MIT
