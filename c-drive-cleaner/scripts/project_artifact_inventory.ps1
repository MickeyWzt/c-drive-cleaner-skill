[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,

    [ValidateRange(0, 1048576)]
    [int]$MinSizeMB = 16,

    [ValidateRange(1, 500)]
    [int]$MaxCandidates = 200,

    [ValidateRange(1, 600)]
    [int]$ProgressIntervalSeconds = 15,

    [ValidateRange(10, 500)]
    [int]$SampleLimit = 50,

    [string]$ReportPath
)

$ErrorActionPreference = "Continue"

function Convert-ArtifactBytes {
    param([Int64]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Get-NormalizedArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $normalized = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
    if ($normalized.Length -eq 2 -and $normalized[1] -eq ':') {
        return $normalized + "\"
    }
    return $normalized
}

function Test-ArtifactUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $fullPath = Get-NormalizedArtifactPath -Path $Path
    $fullRoot = Get-NormalizedArtifactPath -Path $Root
    if ($fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $prefix = if ($fullRoot.EndsWith("\")) { $fullRoot } else { $fullRoot + "\" }
    return $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Add-ArtifactSample {
    param(
        [Parameter(Mandatory = $true)]$List,
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][int]$Limit
    )
    if ($List.Count -lt $Limit) {
        $List.Add($Value) | Out-Null
    }
}

function Get-ProjectEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$StartPath,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $manifestNames = @(
        "package.json", "Cargo.toml", "pyproject.toml", "requirements.txt",
        "setup.py", "Pipfile", "go.mod"
    )
    $lockNames = @(
        "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lock", "bun.lockb",
        "Cargo.lock", "uv.lock", "poetry.lock", "Pipfile.lock"
    )

    $current = [System.IO.DirectoryInfo]::new($StartPath)
    while ($null -ne $current -and (Test-ArtifactUnderRoot -Path $current.FullName -Root $Root)) {
        $manifests = New-Object System.Collections.Generic.List[string]
        $locks = New-Object System.Collections.Generic.List[string]
        foreach ($name in $manifestNames) {
            $candidate = Join-Path $current.FullName $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $manifests.Add($candidate) | Out-Null
            }
        }
        foreach ($name in $lockNames) {
            $candidate = Join-Path $current.FullName $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $locks.Add($candidate) | Out-Null
            }
        }

        if ($manifests.Count -gt 0) {
            return [PSCustomObject]@{
                ProjectRoot = $current.FullName
                Manifests = [string[]]$manifests
                LockFiles = [string[]]$locks
            }
        }

        if ($current.FullName.Equals((Get-NormalizedArtifactPath -Path $Root), [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $current = $current.Parent
    }

    return [PSCustomObject]@{
        ProjectRoot = $null
        Manifests = [string[]]@()
        LockFiles = [string[]]@()
    }
}

function Measure-ArtifactTree {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$ProgressSeconds,
        [Parameter(Mandatory = $true)][int]$Samples
    )

    $bytes = [Int64]0
    $fileCount = [Int64]0
    $directoryCount = [Int64]0
    $errorCount = [Int64]0
    $reparseCount = [Int64]0
    $newestFile = [datetime]::MinValue
    $errors = New-Object System.Collections.Generic.List[string]
    $reparseSamples = New-Object System.Collections.Generic.List[string]
    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    $queue.Enqueue($Path)
    $lastProgress = Get-Date

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $directoryCount += 1
        try {
            foreach ($entry in [System.IO.Directory]::EnumerateFileSystemEntries($current)) {
                try {
                    $attributes = [System.IO.File]::GetAttributes($entry)
                    if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                        $reparseCount += 1
                        Add-ArtifactSample -List $reparseSamples -Value $entry -Limit $Samples
                        continue
                    }
                    if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) {
                        $queue.Enqueue($entry)
                        continue
                    }

                    $file = [System.IO.FileInfo]::new($entry)
                    $bytes += [Int64]$file.Length
                    $fileCount += 1
                    if ($file.LastWriteTime -gt $newestFile) { $newestFile = $file.LastWriteTime }
                } catch {
                    $errorCount += 1
                    Add-ArtifactSample -List $errors -Value "$entry :: $($_.Exception.Message)" -Limit $Samples
                }
            }
        } catch {
            $errorCount += 1
            Add-ArtifactSample -List $errors -Value "$current :: $($_.Exception.Message)" -Limit $Samples
        }

        $now = Get-Date
        if (($now - $lastProgress).TotalSeconds -ge $ProgressSeconds) {
            Write-Information ("Measuring candidate: {0}; {1} files; {2}; {3} directories pending" -f
                $Path, $fileCount, (Convert-ArtifactBytes $bytes), $queue.Count) -InformationAction Continue
            $lastProgress = $now
        }
    }

    [PSCustomObject]@{
        Bytes = $bytes
        HumanSize = Convert-ArtifactBytes $bytes
        FileCount = $fileCount
        DirectoryCount = $directoryCount
        NewestFile = if ($newestFile -eq [datetime]::MinValue) { $null } else { $newestFile.ToString("o") }
        ErrorCount = $errorCount
        Errors = [string[]]$errors
        SkippedReparsePointCount = $reparseCount
        SkippedReparsePointSamples = [string[]]$reparseSamples
    }
}

$rootItem = Get-Item -Force -LiteralPath $RootPath -ErrorAction Stop
if (-not $rootItem.PSIsContainer) { throw "RootPath must be a directory: $RootPath" }
if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "RootPath must not be a reparse point: $RootPath"
}

$root = Get-NormalizedArtifactPath -Path $rootItem.FullName
$safeNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
@("node_modules", "target", ".next", ".nuxt", ".svelte-kit", ".turbo", ".vite", "coverage", "__pycache__", ".pytest_cache") |
    ForEach-Object { [void]$safeNames.Add($_) }
$reviewNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
@("build", "dist", "out", "artifacts") | ForEach-Object { [void]$reviewNames.Add($_) }

$startedAt = Get-Date
$lastProgressAt = $startedAt
$traversedDirectories = [Int64]0
$skippedTraversalReparseCount = [Int64]0
$traversalErrorCount = [Int64]0
$skippedTraversalReparseSamples = New-Object System.Collections.Generic.List[string]
$traversalErrors = New-Object System.Collections.Generic.List[string]
$candidates = New-Object System.Collections.Generic.List[object]
$queue = New-Object 'System.Collections.Generic.Queue[string]'
$queue.Enqueue($root)
$minimumBytes = [Int64]$MinSizeMB * 1MB

while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    $traversedDirectories += 1
    try {
        foreach ($entry in [System.IO.Directory]::EnumerateDirectories($current)) {
            try {
                $attributes = [System.IO.File]::GetAttributes($entry)
                if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $skippedTraversalReparseCount += 1
                    Add-ArtifactSample -List $skippedTraversalReparseSamples -Value $entry -Limit $SampleLimit
                    continue
                }

                $name = [System.IO.Path]::GetFileName($entry)
                $baseClass = $null
                if ($safeNames.Contains($name)) {
                    $baseClass = "safe_rebuildable"
                } elseif ($reviewNames.Contains($name) -or $name.IndexOf("repack", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $baseClass = "review_output"
                }

                if ($null -eq $baseClass) {
                    if ($name -notin @(".git", ".svn")) { $queue.Enqueue($entry) }
                    continue
                }

                $measurement = Measure-ArtifactTree -Path $entry -ProgressSeconds $ProgressIntervalSeconds -Samples $SampleLimit
                if ($measurement.Bytes -lt $minimumBytes) { continue }
                $evidence = Get-ProjectEvidence -StartPath ([System.IO.Path]::GetDirectoryName($entry)) -Root $root
                $classification = if ($measurement.ErrorCount -gt 0 -or $measurement.SkippedReparsePointCount -gt 0) {
                    "review_incomplete_scan"
                } elseif ($baseClass -eq "safe_rebuildable" -and $null -eq $evidence.ProjectRoot) {
                    "review_missing_manifest"
                } else {
                    $baseClass
                }
                $recovery = switch ($name.ToLowerInvariant()) {
                    "node_modules" { "Reinstall dependencies from the preserved project manifest and lock file." }
                    "target" { "Rebuild with Cargo from the preserved Cargo.toml and Cargo.lock." }
                    default { "Rerun the owning project's build, test, or package command." }
                }

                $candidates.Add([PSCustomObject]@{
                    Classification = $classification
                    Path = Get-NormalizedArtifactPath -Path $entry
                    Name = $name
                    ProjectRoot = $evidence.ProjectRoot
                    Manifests = $evidence.Manifests
                    LockFiles = $evidence.LockFiles
                    Recovery = $recovery
                    Bytes = $measurement.Bytes
                    HumanSize = $measurement.HumanSize
                    FileCount = $measurement.FileCount
                    DirectoryCount = $measurement.DirectoryCount
                    NewestFile = $measurement.NewestFile
                    ErrorCount = $measurement.ErrorCount
                    Errors = $measurement.Errors
                    SkippedReparsePointCount = $measurement.SkippedReparsePointCount
                    SkippedReparsePointSamples = $measurement.SkippedReparsePointSamples
                }) | Out-Null
            } catch {
                $traversalErrorCount += 1
                Add-ArtifactSample -List $traversalErrors -Value "$entry :: $($_.Exception.Message)" -Limit $SampleLimit
            }
        }
    } catch {
        $traversalErrorCount += 1
        Add-ArtifactSample -List $traversalErrors -Value "$current :: $($_.Exception.Message)" -Limit $SampleLimit
    }

    $now = Get-Date
    if (($now - $lastProgressAt).TotalSeconds -ge $ProgressIntervalSeconds) {
        Write-Information ("Artifact inventory: {0} directories traversed; {1} candidates; {2} pending" -f
            $traversedDirectories, $candidates.Count, $queue.Count) -InformationAction Continue
        $lastProgressAt = $now
    }
}

$allCandidateArray = @($candidates | Sort-Object Bytes -Descending)
$candidateArray = @($allCandidateArray | Select-Object -First $MaxCandidates)
$summary = @($allCandidateArray | Group-Object Classification | ForEach-Object {
    $sum = [Int64](($_.Group | Measure-Object -Property Bytes -Sum).Sum)
    [PSCustomObject]@{
        Classification = $_.Name
        CandidateCount = $_.Count
        Bytes = $sum
        HumanSize = Convert-ArtifactBytes $sum
    }
})
$finishedAt = Get-Date
$report = [PSCustomObject]@{
    StartedAt = $startedAt.ToString("o")
    FinishedAt = $finishedAt.ToString("o")
    ElapsedSeconds = [Math]::Round(($finishedAt - $startedAt).TotalSeconds, 1)
    Root = $root
    Mode = "ReadOnlyInventory"
    MinSizeMB = $MinSizeMB
    TraversedDirectoryCount = $traversedDirectories
    TraversalErrorCount = $traversalErrorCount
    TraversalErrors = [string[]]$traversalErrors
    SkippedTraversalReparsePointCount = $skippedTraversalReparseCount
    SkippedTraversalReparsePointSamples = [string[]]$skippedTraversalReparseSamples
    TotalCandidateCount = $allCandidateArray.Count
    ReturnedCandidateCount = $candidateArray.Count
    CandidatesTruncated = ($allCandidateArray.Count -gt $candidateArray.Count)
    Summary = $summary
    Candidates = $candidateArray
    Notes = @(
        "This script reads filesystem metadata only and never deletes anything.",
        "safe_rebuildable means the directory name is normally reproducible and a nearby project manifest was found; deletion still requires explicit item-level approval.",
        "review_output, review_missing_manifest, and review_incomplete_scan are not safe deletion recommendations.",
        "Do not treat build, dist, out, artifacts, repack, source trees, or delivery files as disposable without project-specific verification.",
        "Before any approved deletion, validate a fixed target list, reject target or nested reparse points, record protected manifests and deliverables, and verify them again afterward."
    )
}

$json = $report | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

$report
