[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Clean')]
    [string]$Mode = 'Audit',

    [ValidatePattern('^[A-Za-z]:$')]
    [string]$Drive = 'C:',

    [ValidateRange(0, 3650)]
    [int]$MinAgeDays = 7,

    [switch]$IncludeBrowserCaches,
    [switch]$IncludeRecycleBin,
    [switch]$ScanLargeFiles,
    [switch]$ConfirmClean,

    [string]$ReportPath
)

$ErrorActionPreference = 'Continue'

function Convert-Bytes {
    param([Int64]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0} B' -f $Bytes)
}

function Get-DriveSnapshot {
    param([string]$DriveName)
    $root = $DriveName.TrimEnd(':') + ':\'
    $driveInfo = New-Object System.IO.DriveInfo($root)
    $usedBytes = [Int64]($driveInfo.TotalSize - $driveInfo.AvailableFreeSpace)
    [PSCustomObject]@{
        Name = $DriveName
        FreeBytes = [Int64]$driveInfo.AvailableFreeSpace
        UsedBytes = $usedBytes
        TotalBytes = [Int64]$driveInfo.TotalSize
        Free = Convert-Bytes ([Int64]$driveInfo.AvailableFreeSpace)
        Used = Convert-Bytes $usedBytes
        Total = Convert-Bytes ([Int64]$driveInfo.TotalSize)
    }
}

function Resolve-SafePath {
    param([string]$Path)
    try {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop | Select-Object -First 1
        return $resolved.ProviderPath
    } catch {
        return $null
    }
}

function Test-UnderPath {
    param(
        [string]$Path,
        [string]$BasePath
    )
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $fullBase = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    return $fullPath.Equals($fullBase, [StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($fullBase + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Get-CleanupTargets {
    param([string]$DriveName)

    $targets = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $driveRoot = $DriveName.TrimEnd(':') + ':\'

    function Add-Target {
        param(
            [string]$Category,
            [string]$Path,
            [bool]$Enabled = $true
        )

        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        $resolved = Resolve-SafePath -Path $Path
        if ($null -eq $resolved) {
            $targets.Add([PSCustomObject]@{
                Category = $Category
                Path = $Path
                ResolvedPath = $null
                Enabled = $false
                Exists = $false
                Reason = 'Path does not exist'
            })
            return
        }

        if (-not (Test-UnderPath -Path $resolved -BasePath $driveRoot)) {
            $targets.Add([PSCustomObject]@{
                Category = $Category
                Path = $Path
                ResolvedPath = $resolved
                Enabled = $false
                Exists = $true
                Reason = 'Path is outside target drive'
            })
            return
        }

        if ($seen.Add($resolved)) {
            $targets.Add([PSCustomObject]@{
                Category = $Category
                Path = $Path
                ResolvedPath = $resolved
                Enabled = $Enabled
                Exists = $true
                Reason = if ($Enabled) { 'Included' } else { 'Not selected' }
            })
        }
    }

    Add-Target -Category 'User temp' -Path $env:TEMP
    Add-Target -Category 'User temp' -Path $env:TMP
    Add-Target -Category 'Windows temp' -Path (Join-Path $DriveName 'Windows\Temp')

    if ($IncludeBrowserCaches) {
        $local = [Environment]::GetFolderPath('LocalApplicationData')
        Add-Target -Category 'Microsoft Edge cache' -Path (Join-Path $local 'Microsoft\Edge\User Data\Default\Cache\Cache_Data')
        Add-Target -Category 'Microsoft Edge code cache' -Path (Join-Path $local 'Microsoft\Edge\User Data\Default\Code Cache')
        Add-Target -Category 'Google Chrome cache' -Path (Join-Path $local 'Google\Chrome\User Data\Default\Cache\Cache_Data')
        Add-Target -Category 'Google Chrome code cache' -Path (Join-Path $local 'Google\Chrome\User Data\Default\Code Cache')
        Add-Target -Category 'Brave cache' -Path (Join-Path $local 'BraveSoftware\Brave-Browser\User Data\Default\Cache\Cache_Data')

        $firefoxRoot = Join-Path $local 'Mozilla\Firefox\Profiles'
        if (Test-Path -LiteralPath $firefoxRoot) {
            Get-ChildItem -LiteralPath $firefoxRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                Add-Target -Category 'Firefox cache' -Path (Join-Path $_.FullName 'cache2\entries')
                Add-Target -Category 'Firefox startup cache' -Path (Join-Path $_.FullName 'startupCache')
            }
        } else {
            Add-Target -Category 'Firefox cache' -Path $firefoxRoot -Enabled $false
        }
    }

    return $targets
}

function Get-OldFiles {
    param(
        [string]$Root,
        [datetime]$Cutoff
    )

    $scanErrors = @()
    $files = @(
        Get-ChildItem -LiteralPath $Root -Force -Recurse -File -ErrorAction SilentlyContinue -ErrorVariable scanErrors |
            Where-Object { $_.LastWriteTime -lt $Cutoff }
    )

    [PSCustomObject]@{
        Files = $files
        Errors = @($scanErrors | ForEach-Object { $_.Exception.Message } | Select-Object -Unique)
    }
}

function Measure-Target {
    param(
        [object]$Target,
        [datetime]$Cutoff
    )

    if (-not $Target.Enabled -or -not $Target.Exists -or $null -eq $Target.ResolvedPath) {
        return [PSCustomObject]@{
            Category = $Target.Category
            Path = $Target.Path
            ResolvedPath = $Target.ResolvedPath
            Included = $false
            FileCount = 0
            Bytes = 0
            HumanSize = '0 B'
            Errors = @($Target.Reason)
        }
    }

    $scan = Get-OldFiles -Root $Target.ResolvedPath -Cutoff $Cutoff
    $bytes = [Int64](($scan.Files | Measure-Object -Property Length -Sum).Sum)
    if ($null -eq $bytes) { $bytes = 0 }

    [PSCustomObject]@{
        Category = $Target.Category
        Path = $Target.Path
        ResolvedPath = $Target.ResolvedPath
        Included = $true
        FileCount = $scan.Files.Count
        Bytes = $bytes
        HumanSize = Convert-Bytes $bytes
        Errors = @($scan.Errors)
    }
}

function Remove-TargetFiles {
    param(
        [object]$Target,
        [datetime]$Cutoff
    )

    $scan = Get-OldFiles -Root $Target.ResolvedPath -Cutoff $Cutoff
    $deletedBytes = [Int64]0
    $deletedCount = 0
    $errors = New-Object System.Collections.Generic.List[string]

    foreach ($file in $scan.Files) {
        if (-not (Test-UnderPath -Path $file.FullName -BasePath $Target.ResolvedPath)) {
            $errors.Add('Refused outside allowlist: ' + $file.FullName)
            continue
        }

        try {
            $length = [Int64]$file.Length
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $deletedBytes += $length
            $deletedCount += 1
        } catch {
            $errors.Add($file.FullName + ': ' + $_.Exception.Message)
        }
    }

    foreach ($err in $scan.Errors) { $errors.Add($err) }

    [PSCustomObject]@{
        Category = $Target.Category
        Path = $Target.Path
        DeletedFiles = $deletedCount
        DeletedBytes = $deletedBytes
        HumanDeleted = Convert-Bytes $deletedBytes
        Errors = @($errors | Select-Object -Unique)
    }
}

function Get-LargeFileHints {
    param([string]$DriveName)
    $userRoot = Join-Path $DriveName 'Users'
    if (-not (Test-Path -LiteralPath $userRoot)) { return @() }

    Get-ChildItem -LiteralPath $userRoot -Force -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Length -ge 1GB -and
            $_.FullName -notlike '*\AppData\*' -and
            $_.FullName -notlike '*\OneDrive\*'
        } |
        Sort-Object Length -Descending |
        Select-Object -First 25 @{Name='Path';Expression={$_.FullName}},
            @{Name='Bytes';Expression={[Int64]$_.Length}},
            @{Name='HumanSize';Expression={Convert-Bytes ([Int64]$_.Length)}},
            LastWriteTime
}

$startedAt = Get-Date
$cutoff = (Get-Date).AddDays(-1 * $MinAgeDays)
$before = Get-DriveSnapshot -DriveName $Drive
$targets = Get-CleanupTargets -DriveName $Drive
$measurements = @($targets | ForEach-Object { Measure-Target -Target $_ -Cutoff $cutoff })
$cleanupResults = @()
$recycleResult = $null

if ($Mode -eq 'Clean') {
    if (-not $ConfirmClean) {
        throw 'Cleanup mode requires -ConfirmClean. Run Audit first and get explicit user approval.'
    }

    foreach ($target in $targets | Where-Object { $_.Enabled -and $_.Exists -and $null -ne $_.ResolvedPath }) {
        $cleanupResults += Remove-TargetFiles -Target $target -Cutoff $cutoff
    }

    if ($IncludeRecycleBin) {
        try {
            Clear-RecycleBin -DriveLetter $Drive.TrimEnd(':') -Force -ErrorAction Stop
            $recycleResult = [PSCustomObject]@{ Included = $true; Cleared = $true; Error = $null }
        } catch {
            $recycleResult = [PSCustomObject]@{ Included = $true; Cleared = $false; Error = $_.Exception.Message }
        }
    }
}

$after = Get-DriveSnapshot -DriveName $Drive
$largeFiles = if ($ScanLargeFiles) { @(Get-LargeFileHints -DriveName $Drive) } else { @() }
$estimated = [Int64](($measurements | Where-Object { $_.Included } | Measure-Object -Property Bytes -Sum).Sum)
if ($null -eq $estimated) { $estimated = 0 }
$deleted = [Int64](($cleanupResults | Measure-Object -Property DeletedBytes -Sum).Sum)
if ($null -eq $deleted) { $deleted = 0 }

$report = [PSCustomObject]@{
    StartedAt = $startedAt.ToString('o')
    FinishedAt = (Get-Date).ToString('o')
    Mode = $Mode
    Drive = $Drive
    MinAgeDays = $MinAgeDays
    IncludeBrowserCaches = [bool]$IncludeBrowserCaches
    IncludeRecycleBin = [bool]$IncludeRecycleBin
    ScanLargeFiles = [bool]$ScanLargeFiles
    FreeSpaceBefore = $before
    FreeSpaceAfter = $after
    EstimatedReclaimableBytes = $estimated
    EstimatedReclaimable = Convert-Bytes $estimated
    DeletedBytes = $deleted
    Deleted = Convert-Bytes $deleted
    Targets = $measurements
    CleanupResults = $cleanupResults
    RecycleBin = $recycleResult
    LargeFileHints = $largeFiles
}

$json = $report | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $json | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

$report
