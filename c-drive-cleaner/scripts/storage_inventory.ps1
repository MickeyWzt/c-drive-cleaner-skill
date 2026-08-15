[CmdletBinding()]
param(
    [ValidatePattern("^[A-Za-z]:$")]
    [string]$Drive = "C:",

    [string]$RootPath,

    [ValidateRange(1, 8)]
    [int]$MaxDepth = 5,

    [ValidateRange(5, 100)]
    [int]$TopPerDepth = 25,

    [ValidateRange(5, 200)]
    [int]$TopFileCount = 50,

    [ValidateRange(16, 102400)]
    [int]$LargeFileMinMB = 128,

    [ValidateRange(1, 600)]
    [int]$ProgressIntervalSeconds = 15,

    [ValidateRange(10, 500)]
    [int]$SampleLimit = 50,

    [string]$ReportPath
)

$ErrorActionPreference = "Continue"

function Convert-InventoryBytes {
    param([Int64]$Bytes)
    $sign = if ($Bytes -lt 0) { "-" } else { "" }
    $absoluteBytes = [Math]::Abs($Bytes)
    if ($absoluteBytes -ge 1TB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1TB)) TB" }
    if ($absoluteBytes -ge 1GB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1GB)) GB" }
    if ($absoluteBytes -ge 1MB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1MB)) MB" }
    if ($absoluteBytes -ge 1KB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1KB)) KB" }
    return "$Bytes B"
}

function Get-NormalizedInventoryPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $normalized = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
    if ($normalized.Length -eq 2 -and $normalized[1] -eq ':') {
        return $normalized + "\"
    }
    return $normalized
}

function Add-Sample {
    param(
        [Parameter(Mandatory = $true)]$List,
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][int]$Limit
    )
    if ($List.Count -lt $Limit) {
        $List.Add($Value) | Out-Null
    }
}

function Add-BucketBytes {
    param(
        [Parameter(Mandatory = $true)]$Buckets,
        [Parameter(Mandatory = $true)][int]$Depth,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][Int64]$Bytes
    )
    $depthBuckets = $Buckets[$Depth]
    if ($depthBuckets.ContainsKey($Path)) {
        [void]($depthBuckets[$Path] = [Int64]($depthBuckets[$Path] + $Bytes))
    } else {
        [void]($depthBuckets[$Path] = $Bytes)
    }
}

$requestedRoot = if ([string]::IsNullOrWhiteSpace($RootPath)) {
    $Drive.TrimEnd(":") + ":\"
} else {
    $RootPath
}

try {
    $rootItem = Get-Item -Force -LiteralPath $requestedRoot -ErrorAction Stop
} catch {
    throw "Inventory root is unavailable: $requestedRoot. $($_.Exception.Message)"
}

if (-not $rootItem.PSIsContainer) {
    throw "Inventory root must be a directory: $requestedRoot"
}
if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Inventory root must not be a reparse point: $requestedRoot"
}

$root = Get-NormalizedInventoryPath -Path $rootItem.FullName
$rootWithSeparator = if ($root.EndsWith("\")) { $root } else { $root + "\" }
$driveRoot = Get-NormalizedInventoryPath -Path ([System.IO.Path]::GetPathRoot($root))
$isWholeDrive = [string]::Equals($root, $driveRoot, [StringComparison]::OrdinalIgnoreCase)
$driveInfo = [System.IO.DriveInfo]::new($driveRoot)
$driveSnapshot = [PSCustomObject]@{
    Name = $driveInfo.Name
    FreeBytes = [Int64]$driveInfo.AvailableFreeSpace
    UsedBytes = [Int64]($driveInfo.TotalSize - $driveInfo.AvailableFreeSpace)
    TotalBytes = [Int64]$driveInfo.TotalSize
    Free = Convert-InventoryBytes ([Int64]$driveInfo.AvailableFreeSpace)
    Used = Convert-InventoryBytes ([Int64]($driveInfo.TotalSize - $driveInfo.AvailableFreeSpace))
    Total = Convert-InventoryBytes ([Int64]$driveInfo.TotalSize)
}

$startedAt = Get-Date
$lastProgressAt = $startedAt
$logicalBytes = [Int64]0
$fileCount = [Int64]0
$directoryCount = [Int64]0
$inaccessibleCount = [Int64]0
$skippedReparsePointCount = [Int64]0
$inaccessibleSamples = New-Object System.Collections.Generic.List[string]
$skippedReparsePointSamples = New-Object System.Collections.Generic.List[string]
$largeFiles = New-Object System.Collections.Generic.List[object]
$largeFileMinimumBytes = [Int64]$LargeFileMinMB * 1MB

$buckets = @{}
for ($depth = 1; $depth -le $MaxDepth; $depth++) {
    $buckets[$depth] = New-Object 'System.Collections.Generic.Dictionary[string,long]' ([System.StringComparer]::OrdinalIgnoreCase)
}

$queue = New-Object 'System.Collections.Generic.Queue[string]'
$queue.Enqueue($root)

while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    $directoryCount += 1

    try {
        $entries = [System.IO.Directory]::EnumerateFileSystemEntries($current)
        foreach ($entry in $entries) {
            try {
                $attributes = [System.IO.File]::GetAttributes($entry)
                if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $skippedReparsePointCount += 1
                    Add-Sample -List $skippedReparsePointSamples -Value $entry -Limit $SampleLimit
                    continue
                }

                if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) {
                    $queue.Enqueue($entry)
                    continue
                }

                $file = [System.IO.FileInfo]::new($entry)
                $length = [Int64]$file.Length
                $logicalBytes += $length
                $fileCount += 1

                $relative = if ($entry.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
                    $entry.Substring($rootWithSeparator.Length)
                } else {
                    $file.Name
                }
                $parts = @($relative.Split([char]'\', [System.StringSplitOptions]::RemoveEmptyEntries))
                $maximumFileDepth = [Math]::Min($MaxDepth, [Math]::Max(0, $parts.Count - 1))
                for ($depth = 1; $depth -le $maximumFileDepth; $depth++) {
                    $bucketPath = Join-Path $root ($parts[0..($depth - 1)] -join "\")
                    Add-BucketBytes -Buckets $buckets -Depth $depth -Path $bucketPath -Bytes $length
                }

                if ($length -ge $largeFileMinimumBytes) {
                    $largeFiles.Add([PSCustomObject]@{
                        Path = $file.FullName
                        Bytes = $length
                        HumanSize = Convert-InventoryBytes $length
                        LastWriteTime = $file.LastWriteTime
                    }) | Out-Null
                }
            } catch {
                $inaccessibleCount += 1
                Add-Sample -List $inaccessibleSamples -Value "$entry :: $($_.Exception.Message)" -Limit $SampleLimit
            }
        }
    } catch {
        $inaccessibleCount += 1
        Add-Sample -List $inaccessibleSamples -Value "$current :: $($_.Exception.Message)" -Limit $SampleLimit
    }

    $now = Get-Date
    if (($now - $lastProgressAt).TotalSeconds -ge $ProgressIntervalSeconds) {
        Write-Information ("Inventory progress: {0} directories, {1} files, {2}, {3} inaccessible, {4} pending" -f
            $directoryCount, $fileCount, (Convert-InventoryBytes $logicalBytes), $inaccessibleCount, $queue.Count) -InformationAction Continue
        $lastProgressAt = $now
    }
}

$directoryHotspots = New-Object System.Collections.Generic.List[object]
for ($depth = 1; $depth -le $MaxDepth; $depth++) {
    $buckets[$depth].GetEnumerator() |
        Sort-Object Value -Descending |
        Select-Object -First $TopPerDepth |
        ForEach-Object {
            $directoryHotspots.Add([PSCustomObject]@{
                Depth = $depth
                Path = $_.Key
                Bytes = [Int64]$_.Value
                HumanSize = Convert-InventoryBytes ([Int64]$_.Value)
            }) | Out-Null
        }
}

$topFiles = @($largeFiles | Sort-Object Bytes -Descending | Select-Object -First $TopFileCount)
$coverageGap = if ($isWholeDrive) { [Int64]($driveSnapshot.UsedBytes - $logicalBytes) } else { $null }
$coverageGapHuman = if ($null -ne $coverageGap) { Convert-InventoryBytes $coverageGap } else { $null }
$inaccessibleSampleArray = [string[]]$inaccessibleSamples
$skippedReparsePointSampleArray = [string[]]$skippedReparsePointSamples
$directoryHotspotArray = [object[]]$directoryHotspots
$finishedAt = Get-Date
$report = [PSCustomObject]@{
    StartedAt = $startedAt.ToString("o")
    FinishedAt = $finishedAt.ToString("o")
    ElapsedSeconds = [Math]::Round(($finishedAt - $startedAt).TotalSeconds, 1)
    Root = $root
    IsWholeDrive = $isWholeDrive
    DriveSnapshot = $driveSnapshot
    LogicalBytesScanned = $logicalBytes
    LogicalSizeScanned = Convert-InventoryBytes $logicalBytes
    CoverageGapBytes = $coverageGap
    CoverageGap = $coverageGapHuman
    FileCount = $fileCount
    DirectoryCount = $directoryCount
    InaccessibleCount = $inaccessibleCount
    InaccessibleSamples = $inaccessibleSampleArray
    SkippedReparsePointCount = $skippedReparsePointCount
    SkippedReparsePointSamples = $skippedReparsePointSampleArray
    DirectoryHotspots = $directoryHotspotArray
    TopFiles = $topFiles
    Notes = @(
        "Inventory reads filesystem metadata such as path, size, timestamps, and attributes; it does not open private document contents.",
        "Directory sizes are logical file-size sums, not guaranteed physical allocation.",
        "NTFS hard links, especially WinSxS files also linked into Windows directories, can make directory totals overlap.",
        "Protected paths are reported as inaccessible; reparse points are never followed.",
        "Use the cleanup audit for reclaimable estimates. Inventory results are advisory and never authorize deletion."
    )
}

$json = $report | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

$report
