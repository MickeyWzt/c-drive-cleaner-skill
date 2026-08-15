# C Drive Cleanup Safety Reference

## Allowed Automated Cleanup Categories

The bundled script may automate only these categories:

- User temp directories from `%TEMP%` and `%TMP%`.
- `C:\Windows\Temp`.
- Common browser Cache, Code Cache, and GPUCache directories when explicitly requested. Service Worker storage and browser profile data are excluded.
- Recycle bin cleanup when explicitly requested.
- Windows Update download cache when explicitly requested or included by a deep preset.
- Delivery Optimization cache when explicitly requested or included by a deep preset.
- Windows Error Reporting archives and queues when explicitly requested or included by a deep preset.
- Explorer thumbnail and icon cache database files when explicitly requested or included by a deep preset.
- DirectX and NVIDIA shader caches when explicitly requested or included by a deep preset.
- Diagnostic dump files such as user crash dumps, Windows minidumps, and `C:\Windows\MEMORY.DMP` when explicitly requested or included by a deep preset.
- Overwolf crash dumps under `%LOCALAPPDATA%\Overwolf\CrashDumps` when diagnostic dumps are explicitly requested.
- pip, npm/npx, and uv download caches only with their per-ecosystem switches. `-IncludePackageManagerCaches` is a compatibility alias for all three and is never included by a preset.
- NVIDIA App downloaded driver/application artifacts only with `-IncludeNvidiaDownloadCache`. This exact `ProgramData` path is the only exception to the general `ProgramData` prohibition.
- Squirrel installer temporary files only with `-IncludeInstallerTemp`.
- Windows component store cleanup through `dism.exe /Online /Cleanup-Image /StartComponentCleanup` when explicitly requested or included by the maximum preset.

All automated file deletion must use an age threshold, defaulting to files older than 7 days, except recycle bin cleanup. Component store cleanup must use DISM instead of manually deleting WinSxS files.

## Never Delete Automatically

Do not automatically delete:

- `C:\Windows`, except `C:\Windows\Temp` contents.
- `C:\Program Files`, `C:\Program Files (x86)`, or arbitrary `C:\ProgramData` content. The exact NVIDIA download-artifact allowlist above is the only automated `ProgramData` exception.
- User documents, desktop, downloads, pictures, videos, music, source code, OneDrive, Dropbox, iCloud Drive, or synced folders.
- Package manager caches, virtual environments, model caches, or IDE caches unless the user explicitly names the ecosystem and accepts the recovery cost.
- Browser Service Worker storage, cookies, saved passwords, history, extensions, login state, or complete browser profiles. Ordinary browser-cache approval does not cover these.
- Cloud/offline application data such as WPS Cloud Files, music downloads, chat data, model caches, Playwright runtimes, and IDE indexes unless the owning application and recovery cost are reviewed separately.
- Project source trees or broad project/work directories. Known rebuildable child directories still require the project-artifact workflow and item-level approval.
- Conda package directories directly. Use `conda clean --all --dry-run --json`, then an approved `conda clean`; never remove `pkgs` by filesystem recursion.
- Any path that cannot be resolved to an allowed base path.
- `C:\Windows\WinSxS` contents directly. Use DISM component cleanup only.
- `Windows.old`, system restore points, hibernation files, page files, or installed Windows features automatically.

## Risk Notes

- Browser caches are best cleaned after browsers are closed; locked files should be skipped rather than forced.
- Windows Update download cache cleanup can fail or be skipped while updates are actively installing. Prefer an audit first and do not stop Windows update services automatically.
- DISM component cleanup can take a long time and may require administrator rights. Do not use `/ResetBase` by default.
- Admin rights may be needed for `C:\Windows\Temp` and recycle bin cleanup.
- Thumbnail and shader caches will rebuild, so they may temporarily make Explorer, games, or GPU-heavy apps slower on first launch.
- Diagnostic dumps and error reports are useful for troubleshooting. Only clean them after the user accepts losing old diagnostic data.
- Large-file scans are advisory only. They should produce candidates for review, not delete files.
- Directory traversal must skip reparse points and refuse paths outside the resolved allowlist.
- Refuse a cleanup target when the target itself is a reparse point. Skip nested reparse points, count them, and include bounded samples in the report.
- Treat full-drive directory totals as logical size estimates. NTFS hard links can make paths such as WinSxS and System32 overlap; only supported Windows tools can estimate component-store cleanup.
- An empty current-user recycle bin may make `Clear-RecycleBin` report that a path does not exist. Measure only the current user SID directory and distinguish empty/unavailable from a material cleanup failure.
- Do not infer successful cleanup from summed file lengths alone. Compare drive free space before and after; keep both values because active applications can recreate caches during cleanup.
- Do not force-close applications to remove locked cache files. Report and skip locked files.
- Treat application updater downloads as review candidates, not a broad cleanup category. Require an exact file list, an age threshold such as 30 days, proof that the owning application is not running, and preservation of the current installed version and any intentionally retained rollback package.
- Read file metadata for inventory; do not open private document contents merely to estimate disk usage.
- If a deletion attempt is interrupted, do not assume its original preflight remains valid. Re-inventory current state, repeat path and reparse checks, and continue only with still-present approved targets.

## Field-Tested Triage Order

Use this order when a machine is critically low on space:

1. Capture drive capacity and run a comprehensive read-only inventory.
2. Audit high-confidence rebuildable caches (temp, pip/npm, shader caches, downloaded update artifacts, crash dumps, installer temp).
3. Clean only approved categories, then verify actual free-space increase.
4. Run the read-only project artifact inventory. Separate known rebuildable directories with recovery manifests from ambiguous build, release, artifact, and repackaging outputs.
5. Review Downloads and cloud/offline application caches manually or through the owning application.
6. Uninstall unused applications through Windows rather than deleting installation directories.

For remaining high-impact choices, present a numbered decision table. Separate ordinary browser caches from Service Worker/offline storage, and explain the recovery cost of each application cache, model, runtime, project artifact, download, or uninstall candidate.

## Approval Wording

Before cleanup, state the exact categories and threshold, for example:

`I found about 3.2 GB in user temp and Windows temp older than 7 days. Do you want me to delete only those temp files now?`

For deep cleanup, name every category:

`I found about 6.8 GB across temp files, browser caches, Windows Update download cache, recycle bin, shader caches, and diagnostic dumps older than 7 days. Do you want me to clean exactly those categories now?`
