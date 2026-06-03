# Support

C Drive Cleaner Skill is a safety-first cleanup workflow. Support requests should include enough detail to verify that the script stayed inside its documented allowlist.

## Before Opening an Issue

Check these first:

1. Run `Audit` mode before `Clean` mode.
2. Review the JSON report before approving cleanup.
3. Confirm whether the preset is `Standard`, `Deep`, or `Maximum`.
4. Confirm whether browser caches, recycle bin cleanup, or DISM were explicitly enabled.
5. Do not paste private full paths publicly if they contain personal information.

## Where to Ask

- Use a bug report issue for audit errors, report issues, permission handling, or path-safety concerns.
- Use a feature request issue for new cleanup categories or reporting improvements.
- Use the security policy for any behavior that might delete data outside the documented allowlist.

## Useful Details

When asking for help, include:

- Windows version.
- PowerShell version.
- Exact command used.
- Mode, preset, and flags.
- Relevant JSON report excerpts.
- Whether the run was audit-only or clean mode.

## Scope

The skill is designed to clean documented temp/cache locations only. It does not automatically delete Downloads, Documents, Desktop files, source code, synced folders, arbitrary large files, installed apps, restore points, or `Windows.old`.
