# Changelog

All notable changes to C Drive Cleaner Skill will be documented in this file.

This project follows a simple public changelog format inspired by Keep a Changelog. Dates use UTC.

## Unreleased

### Added

- Read-only project artifact inventory that distinguishes manifest-backed reproducible directories from ambiguous build/release output and missing-manifest cases.
- Field-tested references for project-artifact preflight/recovery and ecosystem-native package cache maintenance.
- CI classification coverage for project artifact inventory.
- Read-only full-drive inventory with depth-bounded directory hotspots, large-file hints, inaccessible-path evidence, and reparse-point evidence.
- Explicit opt-ins for pip/npm/uv caches, NVIDIA downloaded update artifacts, Squirrel installer temp, and Overwolf crash dumps.
- Cleanup reports now include actual drive free-space increase and the difference from script-counted deleted bytes.
- CI smoke coverage for the inventory script.
- Basic GitHub Actions CI for PowerShell syntax checks.
- CI badge in the README.
- GitHub topics for Windows disk cleanup, audit-first cleanup, PowerShell, and Codex skills.
- Contributing guide, support guide, roadmap, security policy, and structured issue forms.

### Changed

- Added separate pip, npm/npx, and uv cache switches while retaining the aggregate package-manager switch as a compatibility alias.
- Browser cleanup now includes ordinary GPUCache but explicitly excludes Service Worker storage and browser profile data.
- Safety guidance now covers interrupted cleanup recovery, active-application checks, stale updater review, UTF-8 exact-path manifests, and numbered decision tables.
- Recycle-bin estimates now target only the current user's SID directory.
- Cleanup targets that are themselves reparse points are refused; nested reparse points are skipped and reported with bounded samples.
- Error and reparse-point evidence is bounded to keep reports usable on large machines.
- README now links directly to support, roadmap, contributing, security, and safety reference docs.
- Repository description now emphasizes safety-first auditing and cleanup of reclaimable Windows `C:` drive space.

## 0.1.0

### Added

- Audit-first Windows `C:` drive cleanup workflow.
- PowerShell cleanup script with explicit clean confirmation.
- `Standard`, `Deep`, and `Maximum` presets.
- JSON report output.
- Safety reference for allowlisted cleanup behavior.
