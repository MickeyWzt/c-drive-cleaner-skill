# Package Cache Maintenance

Package caches are rebuildable but ecosystem-specific. Audit and authorize pip, npm/npx, uv, and Conda separately. Prefer the owning tool's maintenance command when it is available and its behavior is understood.

## Scope Rules

- Use `-IncludePipCache`, `-IncludeNpmCache`, or `-IncludeUvCache` so the cleanup script matches the exact ecosystem the user approved.
- Keep `-IncludePackageManagerCaches` only as a backward-compatible alias that enables all three. Use it only when the user approved pip, npm/npx, and uv together.
- Warn that later installs or tools will download packages again.
- Check active processes before cleaning temporary execution environments such as npm `_npx`.
- Record command output, cache size before and after, and actual drive free-space change.

## Native Commands

### pip

Inspect with `python -m pip cache info`. After explicit approval, `python -m pip cache purge` uses pip's supported cleanup path. The bundled cleanup script instead offers age-filtered file cleanup when a partial cleanup is preferred.

### npm and npx

`npm cache verify` can garbage-collect unreferenced data despite its name, so treat it as a mutating maintenance command and obtain approval first. Use `npm cache clean --force` only when the user accepts a complete redownload. Treat `_npx` as separate temporary execution packages; verify no active Node process is using that path and apply an age threshold for partial cleanup.

### uv

Use `uv cache prune` for unreachable objects after approval. Use `uv cache clean` only when the user accepts clearing the remaining cache and redownloading later.

### Conda

Start with:

```powershell
conda clean --all --dry-run --json
```

If only index data is worthwhile, use an explicitly approved `conda clean --index-cache --yes`. Use a separately reviewed `conda clean` command for other reported categories. Never recursively delete Conda `pkgs`, environments, or the Anaconda installation directory.

## Failure Boundaries

- A native command that is unavailable or returns an error is not permission to fall back to broad filesystem deletion.
- A dry-run reporting zero packages does not mean every byte under the Conda installation is disposable.
- Cache command totals and drive free-space changes may differ because applications can write caches concurrently.
