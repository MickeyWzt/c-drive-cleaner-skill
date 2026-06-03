# Contributing to C Drive Cleaner Skill

Thanks for helping improve this safety-first Windows cleanup skill. Contributions are welcome, but cleanup tools need stricter review than ordinary utilities because path mistakes can delete user data.

## Good First Contributions

- Improve documentation for Windows cleanup categories.
- Add tests for path validation and allowlist behavior.
- Improve JSON report formatting.
- Add safer audit-only hints for reclaimable space.
- Document edge cases such as locked files, reparse points, or permission-denied paths.

## Safety Rules

Before expanding cleanup behavior, read `c-drive-cleaner/references/safety.md`.

Contributions must preserve these rules:

- Audit first, clean second.
- Deletion requires explicit clean mode and confirmation.
- Cleanup targets must stay within documented allowlisted temp/cache locations.
- Personal folders such as Downloads, Documents, Desktop, source code, synced folders, app installs, and arbitrary large files must not be deleted automatically.
- Large-file scanning is advisory only.
- Locked or permission-denied files should be reported, not forced.

## Before Opening a Pull Request

1. Explain the cleanup category you are adding or changing.
2. Show the exact paths affected.
3. Include audit output or a test case when possible.
4. Avoid broad wildcard deletion patterns.
5. Keep destructive behavior behind explicit flags.

## Reporting Issues

For bugs, include:

- Windows version.
- PowerShell version if known.
- The exact command used.
- Preset and flags used.
- Whether the run was `Audit` or `Clean`.
- Relevant report JSON snippets.

## Security

If you find a behavior that may delete data outside the documented allowlist, please report it privately first through the process in `SECURITY.md`.