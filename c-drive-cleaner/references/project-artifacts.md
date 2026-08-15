# Project Artifact Review

Use this workflow only after the full-drive inventory shows that development or Codex work directories are material space consumers. Project artifact discovery is read-only and never authorizes deletion.

## Inventory

Run the bundled analyzer against the smallest meaningful user-approved root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/project_artifact_inventory.ps1 -RootPath C:\path\to\projects -MinSizeMB 16 -ReportPath ./project-artifacts.json
```

Interpret the classifications conservatively:

- `safe_rebuildable`: a known reproducible directory name such as `node_modules`, Rust `target`, `.vite`, or a test cache, and a nearby project manifest exists. This is a review candidate, not automatic deletion approval.
- `review_missing_manifest`: the name is normally reproducible but no recovery manifest was found. Do not delete until recovery is proven.
- `review_incomplete_scan`: access errors or nested reparse points prevented a complete safety inventory. Refuse deletion until the cause is resolved and a clean preflight succeeds.
- `review_output`: `build`, `dist`, `out`, `artifacts`, or a repackaging directory. These can contain releases, installers, or user deliverables and are never presumed disposable.

Do not make the user decide whether an entire project will ever be used again when the space can be recovered by removing only reproducible dependencies or compiler output. Preserve source, manifests, lock files, documentation, final deliverables, clean source copies, and intentionally modified installers.

## Preflight Before Any Approved Deletion

Build a fixed target manifest and validate every target again immediately before deletion:

1. Resolve the absolute target and prove it remains under the exact user-approved project root.
2. Require a directory target with an exact path. Do not use wildcard or name-only recursive deletion.
3. Refuse a target that is a reparse point. Scan inside it and refuse the target if any nested reparse point is present.
4. Record logical bytes, file count, newest-file time, recovery evidence, and any scan errors.
5. Record a separate protected-path list for manifests, lock files, source copies, releases, and deliverables that must survive.
6. Check whether relevant package managers, builds, IDEs, or applications are using the target. Skip active targets rather than killing processes for space.
7. State that deletion is permanent, name the exact directories, give the rebuild command, and obtain item-level approval.

For duplicates, compare manifests and lock-file hashes when useful. Matching metadata can strengthen the conclusion that two large trees are repeated builds, but never use matching hashes as permission to delete source trees.

## Execution and Recovery

- Use literal paths from the approved manifest and record `deleted`, `already_absent`, `remaining`, or `error` for every target.
- Make the operation idempotent. If execution was interrupted before deletion, run the entire preflight again. If interrupted during deletion, inventory current state and continue only with still-present approved targets.
- Large `node_modules` and Rust `target` trees can contain more than 100,000 small files and take minutes to remove. Report progress without expanding scope.
- Typical recovery is `npm install`, the owning pnpm/yarn command, or `cargo build` from the preserved project root.
- Do not embed non-ASCII filenames in a Windows PowerShell 5.1 script unless encoding has been verified. Prefer an explicitly UTF-8 manifest or runtime-discovered literal paths, then perform a residual check.

## Verification

After deletion:

1. Prove every approved target is absent or report each remainder.
2. Prove every protected path still exists.
3. Compare drive free space before and after. Keep the logical candidate total and actual free-space increase as separate values.
4. Update the decision report; do not imply that unapproved project outputs were cleaned.
