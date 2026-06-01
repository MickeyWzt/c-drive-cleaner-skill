# C Drive Cleanup Safety Reference

## Allowed Automated Cleanup Categories

The bundled script may automate only these categories:

- User temp directories from `%TEMP%` and `%TMP%`.
- `C:\Windows\Temp`.
- Common browser cache directories when explicitly requested.
- Recycle bin cleanup when explicitly requested.

All automated deletion must use an age threshold, defaulting to files older than 7 days, except recycle bin cleanup.

## Never Delete Automatically

Do not automatically delete:

- `C:\Windows`, except `C:\Windows\Temp` contents.
- `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData`.
- User documents, desktop, downloads, pictures, videos, music, source code, OneDrive, Dropbox, iCloud Drive, or synced folders.
- Package manager caches, virtual environments, model caches, or IDE caches unless the user explicitly names the ecosystem and accepts the recovery cost.
- Any path that cannot be resolved to an allowed base path.

## Risk Notes

- Browser caches are best cleaned after browsers are closed; locked files should be skipped rather than forced.
- Windows update cleanup is better handled through Windows Settings, Storage Sense, or Disk Cleanup because update state can matter.
- Admin rights may be needed for `C:\Windows\Temp` and recycle bin cleanup.
- Large-file scans are advisory only. They should produce candidates for review, not delete files.

## Approval Wording

Before cleanup, state the exact categories and threshold, for example:

`I found about 3.2 GB in user temp and Windows temp older than 7 days. Do you want me to delete only those temp files now?`
