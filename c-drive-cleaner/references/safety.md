# C Drive Cleanup Safety Reference

## Allowed Automated Cleanup Categories

The bundled script may automate only these categories:

- User temp directories from `%TEMP%` and `%TMP%`.
- `C:\Windows\Temp`.
- Common browser cache directories when explicitly requested.
- Recycle bin cleanup when explicitly requested.
- Windows Update download cache when explicitly requested or included by a deep preset.
- Delivery Optimization cache when explicitly requested or included by a deep preset.
- Windows Error Reporting archives and queues when explicitly requested or included by a deep preset.
- Explorer thumbnail and icon cache database files when explicitly requested or included by a deep preset.
- DirectX and NVIDIA shader caches when explicitly requested or included by a deep preset.
- Diagnostic dump files such as user crash dumps, Windows minidumps, and `C:\Windows\MEMORY.DMP` when explicitly requested or included by a deep preset.
- Windows component store cleanup through `dism.exe /Online /Cleanup-Image /StartComponentCleanup` when explicitly requested or included by the maximum preset.

All automated file deletion must use an age threshold, defaulting to files older than 7 days, except recycle bin cleanup. Component store cleanup must use DISM instead of manually deleting WinSxS files.

## Never Delete Automatically

Do not automatically delete:

- `C:\Windows`, except `C:\Windows\Temp` contents.
- `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData`.
- User documents, desktop, downloads, pictures, videos, music, source code, OneDrive, Dropbox, iCloud Drive, or synced folders.
- Package manager caches, virtual environments, model caches, or IDE caches unless the user explicitly names the ecosystem and accepts the recovery cost.
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

## Approval Wording

Before cleanup, state the exact categories and threshold, for example:

`I found about 3.2 GB in user temp and Windows temp older than 7 days. Do you want me to delete only those temp files now?`

For deep cleanup, name every category:

`I found about 6.8 GB across temp files, browser caches, Windows Update download cache, recycle bin, shader caches, and diagnostic dumps older than 7 days. Do you want me to clean exactly those categories now?`
