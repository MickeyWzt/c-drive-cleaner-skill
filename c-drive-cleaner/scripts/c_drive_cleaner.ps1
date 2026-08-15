[CmdletBinding()]
param(
    [ValidateSet("Audit", "Clean")]
    [string]$Mode = "Audit",

    [ValidateSet("Standard", "Deep", "Maximum")]
    [string]$Preset = "Standard",

    [ValidatePattern("^[A-Za-z]:$")]
    [string]$Drive = "C:",

    [ValidateRange(0, 3650)]
    [int]$MinAgeDays = 7,

    [switch]$IncludeBrowserCaches,
    [switch]$IncludeRecycleBin,
    [switch]$IncludeWindowsUpdateCache,
    [switch]$IncludeDeliveryOptimizationCache,
    [switch]$IncludeErrorReports,
    [switch]$IncludeThumbnailCache,
    [switch]$IncludeShaderCaches,
    [switch]$IncludeDiagnosticDumps,
    [switch]$IncludePackageManagerCaches,
    [switch]$IncludePipCache,
    [switch]$IncludeNpmCache,
    [switch]$IncludeUvCache,
    [switch]$IncludeNvidiaDownloadCache,
    [switch]$IncludeInstallerTemp,
    [switch]$ScanLargeFiles,
    [switch]$RunComponentCleanup,
    [switch]$ConfirmClean,

    [string]$ReportPath
)

$ErrorActionPreference = "Continue"

if ($Preset -in @("Deep", "Maximum")) {
    $IncludeBrowserCaches = $true
    $IncludeRecycleBin = $true
    $IncludeWindowsUpdateCache = $true
    $IncludeDeliveryOptimizationCache = $true
    $IncludeErrorReports = $true
    $IncludeThumbnailCache = $true
    $IncludeShaderCaches = $true
    $IncludeDiagnosticDumps = $true
    $ScanLargeFiles = $true
}

if ($Preset -eq "Maximum") {
    $RunComponentCleanup = $true
}

# Backward-compatible aggregate alias. Prefer the per-ecosystem switches so
# audit and cleanup scope can match the user's exact approval.
if ($IncludePackageManagerCaches) {
    $IncludePipCache = $true
    $IncludeNpmCache = $true
    $IncludeUvCache = $true
}

function Convert-Bytes {
    param([Int64]$Bytes)
    $sign = if ($Bytes -lt 0) { "-" } else { "" }
    $absoluteBytes = [Math]::Abs($Bytes)
    if ($absoluteBytes -ge 1TB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1TB)) TB" }
    if ($absoluteBytes -ge 1GB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1GB)) GB" }
    if ($absoluteBytes -ge 1MB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1MB)) MB" }
    if ($absoluteBytes -ge 1KB) { return "$sign$('{0:N2}' -f ($absoluteBytes / 1KB)) KB" }
    return "$Bytes B"
}

function Get-DriveRoot {
    param([string]$DriveName)
    return $DriveName.TrimEnd(":") + ":\"
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Get-DriveSnapshot {
    param([string]$DriveName)
    $root = Get-DriveRoot -DriveName $DriveName
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
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
    $fullBase = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\")
    return $fullPath.Equals($fullBase, [StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($fullBase + "\", [StringComparison]::OrdinalIgnoreCase)
}

function Test-NameMatches {
    param(
        [string]$Name,
        [string[]]$Patterns
    )

    if ($null -eq $Patterns -or $Patterns.Count -eq 0) { return $true }

    foreach ($pattern in $Patterns) {
        if ($Name -like $pattern) { return $true }
    }
    return $false
}

function Get-CleanupTargets {
    param([string]$DriveName)

    $driveRoot = Get-DriveRoot -DriveName $DriveName
    $targets = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    function Add-Target {
        param(
            [string]$Category,
            [string]$Path,
            [bool]$Enabled = $true,
            [string[]]$Patterns = @(),
            [bool]$Recurse = $true,
            [bool]$UseAgeFilter = $true,
            [ValidateSet("DeleteFiles", "RecycleBin")]
            [string]$CleanMethod = "DeleteFiles",
            [string]$Risk = "Low"
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
                Reason = "Path does not exist"
                Patterns = @($Patterns)
                Recurse = $Recurse
                UseAgeFilter = $UseAgeFilter
                CleanMethod = $CleanMethod
                Risk = $Risk
            }) | Out-Null
            return
        }

        $seenKey = "$CleanMethod|$resolved|$($Patterns -join ',')"
        if (-not $seen.Add($seenKey)) { return }

        try {
            $targetItem = Get-Item -Force -LiteralPath $resolved -ErrorAction Stop
            if (($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $targets.Add([PSCustomObject]@{
                    Category = $Category
                    Path = $Path
                    ResolvedPath = $resolved
                    Enabled = $false
                    Exists = $true
                    Reason = "Target itself is a reparse point"
                    Patterns = @($Patterns)
                    Recurse = $Recurse
                    UseAgeFilter = $UseAgeFilter
                    CleanMethod = $CleanMethod
                    Risk = $Risk
                }) | Out-Null
                return
            }
        } catch {
            $targets.Add([PSCustomObject]@{
                Category = $Category
                Path = $Path
                ResolvedPath = $resolved
                Enabled = $false
                Exists = $true
                Reason = "Target validation failed: $($_.Exception.Message)"
                Patterns = @($Patterns)
                Recurse = $Recurse
                UseAgeFilter = $UseAgeFilter
                CleanMethod = $CleanMethod
                Risk = $Risk
            }) | Out-Null
            return
        }

        if (-not (Test-UnderPath -Path $resolved -BasePath $driveRoot)) {
            $targets.Add([PSCustomObject]@{
                Category = $Category
                Path = $Path
                ResolvedPath = $resolved
                Enabled = $false
                Exists = $true
                Reason = "Path is outside target drive"
                Patterns = @($Patterns)
                Recurse = $Recurse
                UseAgeFilter = $UseAgeFilter
                CleanMethod = $CleanMethod
                Risk = $Risk
            }) | Out-Null
            return
        }

        $targets.Add([PSCustomObject]@{
            Category = $Category
            Path = $Path
            ResolvedPath = $resolved
            Enabled = $Enabled
            Exists = $true
            Reason = if ($Enabled) { "Included" } else { "Not selected" }
            Patterns = @($Patterns)
            Recurse = $Recurse
            UseAgeFilter = $UseAgeFilter
            CleanMethod = $CleanMethod
            Risk = $Risk
        }) | Out-Null
    }

    Add-Target -Category "User temp" -Path $env:TEMP
    Add-Target -Category "User temp" -Path $env:TMP
    Add-Target -Category "Windows temp" -Path (Join-Path $driveRoot "Windows\Temp") -Risk "Admin may be required"

    if ($IncludeBrowserCaches) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "Microsoft Edge cache" -Path (Join-Path $local "Microsoft\Edge\User Data\Default\Cache\Cache_Data")
        Add-Target -Category "Microsoft Edge code cache" -Path (Join-Path $local "Microsoft\Edge\User Data\Default\Code Cache")
        Add-Target -Category "Microsoft Edge GPU cache" -Path (Join-Path $local "Microsoft\Edge\User Data\Default\GPUCache")
        Add-Target -Category "Google Chrome cache" -Path (Join-Path $local "Google\Chrome\User Data\Default\Cache\Cache_Data")
        Add-Target -Category "Google Chrome code cache" -Path (Join-Path $local "Google\Chrome\User Data\Default\Code Cache")
        Add-Target -Category "Google Chrome GPU cache" -Path (Join-Path $local "Google\Chrome\User Data\Default\GPUCache")
        Add-Target -Category "Brave cache" -Path (Join-Path $local "BraveSoftware\Brave-Browser\User Data\Default\Cache\Cache_Data")
        Add-Target -Category "Brave code cache" -Path (Join-Path $local "BraveSoftware\Brave-Browser\User Data\Default\Code Cache")
        Add-Target -Category "Brave GPU cache" -Path (Join-Path $local "BraveSoftware\Brave-Browser\User Data\Default\GPUCache")

        $firefoxProfileRoot = Join-Path $local "Mozilla\Firefox\Profiles"
        if (Test-Path -LiteralPath $firefoxProfileRoot) {
            Get-ChildItem -LiteralPath $firefoxProfileRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Add-Target -Category "Firefox cache" -Path (Join-Path $_.FullName "cache2\entries")
                    Add-Target -Category "Firefox startup cache" -Path (Join-Path $_.FullName "startupCache")
                }
        } else {
            Add-Target -Category "Firefox cache" -Path $firefoxProfileRoot -Enabled $false
        }
    }

    if ($IncludeRecycleBin) {
        try {
            $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $currentUserRecycleBin = Join-Path (Join-Path $driveRoot '$Recycle.Bin') $sid
            Add-Target -Category "Recycle Bin (current user)" -Path $currentUserRecycleBin -UseAgeFilter $false -CleanMethod "RecycleBin" -Risk "Deletes user-discarded files permanently"
        } catch {
            Add-Target -Category "Recycle Bin (current user)" -Path (Join-Path $driveRoot '$Recycle.Bin\current-user-unavailable') -Enabled $false -UseAgeFilter $false -CleanMethod "RecycleBin" -Risk "Could not resolve the current user SID"
        }
    }

    if ($IncludeWindowsUpdateCache) {
        Add-Target -Category "Windows Update download cache" -Path (Join-Path $driveRoot "Windows\SoftwareDistribution\Download") -Risk "Admin recommended; skip if updates are actively installing"
    }

    if ($IncludeDeliveryOptimizationCache) {
        Add-Target -Category "Delivery Optimization cache" -Path (Join-Path $driveRoot "ProgramData\Microsoft\Windows\DeliveryOptimization\Cache") -Risk "Admin may be required"
        Add-Target -Category "Delivery Optimization service cache" -Path (Join-Path $driveRoot "Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache") -Risk "Admin may be required"
    }

    if ($IncludeErrorReports) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "Windows Error Reporting archive" -Path (Join-Path $driveRoot "ProgramData\Microsoft\Windows\WER\ReportArchive") -Risk "Removes old diagnostic reports"
        Add-Target -Category "Windows Error Reporting queue" -Path (Join-Path $driveRoot "ProgramData\Microsoft\Windows\WER\ReportQueue") -Risk "Removes queued diagnostic reports"
        Add-Target -Category "User Error Reporting archive" -Path (Join-Path $local "Microsoft\Windows\WER\ReportArchive") -Risk "Removes old diagnostic reports"
        Add-Target -Category "User Error Reporting queue" -Path (Join-Path $local "Microsoft\Windows\WER\ReportQueue") -Risk "Removes queued diagnostic reports"
    }

    if ($IncludeThumbnailCache) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "Explorer thumbnail cache" -Path (Join-Path $local "Microsoft\Windows\Explorer") -Patterns @("thumbcache_*.db", "iconcache_*.db") -Recurse $false -Risk "Thumbnails/icons will rebuild"
    }

    if ($IncludeShaderCaches) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "DirectX shader cache" -Path (Join-Path $local "D3DSCache") -Risk "Shaders will rebuild"
        Add-Target -Category "NVIDIA DX shader cache" -Path (Join-Path $local "NVIDIA\DXCache") -Risk "Shaders will rebuild"
        Add-Target -Category "NVIDIA GL shader cache" -Path (Join-Path $local "NVIDIA\GLCache") -Risk "Shaders will rebuild"
        Add-Target -Category "NVIDIA ProgramData shader cache" -Path (Join-Path $driveRoot "ProgramData\NVIDIA Corporation\NV_Cache") -Risk "Shaders will rebuild"
    }

    if ($IncludeDiagnosticDumps) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "User diagnostic crash dumps" -Path (Join-Path $local "CrashDumps") -Patterns @("*.dmp", "*.mdmp", "*.hdmp") -Risk "Removes debugging dumps"
        Add-Target -Category "Overwolf crash dumps" -Path (Join-Path $local "Overwolf\CrashDumps") -Patterns @("*.dmp", "*.mdmp", "*.hdmp") -Risk "Removes Overwolf debugging dumps"
        Add-Target -Category "Windows minidumps" -Path (Join-Path $driveRoot "Windows\Minidump") -Patterns @("*.dmp") -Risk "Admin may be required; removes debugging dumps"
        Add-Target -Category "Windows memory dump" -Path (Join-Path $driveRoot "Windows\MEMORY.DMP") -Patterns @("*.dmp") -Recurse $false -Risk "Admin may be required; removes kernel memory dump"
    }

    if ($IncludePipCache) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "pip cache" -Path (Join-Path $local "pip\cache") -Risk "Packages will be downloaded again"
    }

    if ($IncludeNpmCache) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "npm content cache" -Path (Join-Path $local "npm-cache\_cacache") -Risk "Packages will be downloaded again"
        Add-Target -Category "npx temporary packages" -Path (Join-Path $local "npm-cache\_npx") -Risk "npx packages will be downloaded again"
    }

    if ($IncludeUvCache) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "uv download cache" -Path (Join-Path $local "uv\cache") -Risk "Packages and Python archives may be downloaded again"
    }

    if ($IncludeNvidiaDownloadCache) {
        Add-Target -Category "NVIDIA downloaded update artifacts" -Path (Join-Path $driveRoot "ProgramData\NVIDIA Corporation\NVIDIA App\UpdateFramework\ota-artifacts") -Risk "Admin may be required; drivers or NVIDIA App packages will be downloaded again"
    }

    if ($IncludeInstallerTemp) {
        $local = [Environment]::GetFolderPath("LocalApplicationData")
        Add-Target -Category "Squirrel installer temporary files" -Path (Join-Path $local "SquirrelTemp") -Risk "Close Electron applications before cleanup"
    }

    return $targets
}

function Get-CandidateFiles {
    param(
        [string]$Root,
        [datetime]$Cutoff,
        [string[]]$Patterns = @(),
        [bool]$Recurse = $true,
        [bool]$UseAgeFilter = $true
    )

    $items = New-Object System.Collections.Generic.List[object]
    $errors = New-Object System.Collections.Generic.List[string]
    $skippedReparsePoints = New-Object System.Collections.Generic.List[string]
    $errorCount = 0
    $skippedReparsePointCount = 0

    try {
        $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
        if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $errorCount += 1
            $skippedReparsePointCount += 1
            $errors.Add("Skipped reparse point: $Root") | Out-Null
            $skippedReparsePoints.Add($Root) | Out-Null
            return [PSCustomObject]@{ Files = $items; Errors = $errors; ErrorCount = $errorCount; SkippedReparsePoints = $skippedReparsePoints; SkippedReparsePointCount = $skippedReparsePointCount }
        }

        if (-not $rootItem.PSIsContainer) {
            if ((Test-NameMatches -Name $rootItem.Name -Patterns $Patterns) -and
                ((-not $UseAgeFilter) -or $rootItem.LastWriteTime -lt $Cutoff)) {
                $items.Add($rootItem) | Out-Null
            }
            return [PSCustomObject]@{ Files = $items; Errors = $errors; ErrorCount = $errorCount; SkippedReparsePoints = $skippedReparsePoints; SkippedReparsePointCount = $skippedReparsePointCount }
        }
    } catch {
        $errorCount += 1
        if ($errors.Count -lt 100) { $errors.Add($_.Exception.Message) | Out-Null }
        return [PSCustomObject]@{ Files = $items; Errors = $errors; ErrorCount = $errorCount; SkippedReparsePoints = $skippedReparsePoints; SkippedReparsePointCount = $skippedReparsePointCount }
    }

    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    $queue.Enqueue($Root)

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()

        try {
            $fileErrors = @()
            Get-ChildItem -LiteralPath $current -Force -File -ErrorAction SilentlyContinue -ErrorVariable fileErrors |
                Where-Object {
                    (Test-NameMatches -Name $_.Name -Patterns $Patterns) -and
                    ((-not $UseAgeFilter) -or $_.LastWriteTime -lt $Cutoff)
                } |
                ForEach-Object { $items.Add($_) | Out-Null }

            foreach ($err in $fileErrors) {
                $errorCount += 1
                if ($errors.Count -lt 100) { $errors.Add($err.Exception.Message) | Out-Null }
            }
        } catch {
            $errorCount += 1
            if ($errors.Count -lt 100) { $errors.Add($_.Exception.Message) | Out-Null }
        }

        if (-not $Recurse) { continue }

        try {
            $dirErrors = @()
            Get-ChildItem -LiteralPath $current -Force -Directory -ErrorAction SilentlyContinue -ErrorVariable dirErrors |
                ForEach-Object {
                    if (($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                        $skippedReparsePointCount += 1
                        if ($skippedReparsePoints.Count -lt 100) {
                            $skippedReparsePoints.Add($_.FullName) | Out-Null
                        }
                    } else {
                        $queue.Enqueue($_.FullName)
                    }
                }

            foreach ($err in $dirErrors) {
                $errorCount += 1
                if ($errors.Count -lt 100) { $errors.Add($err.Exception.Message) | Out-Null }
            }
        } catch {
            $errorCount += 1
            if ($errors.Count -lt 100) { $errors.Add($_.Exception.Message) | Out-Null }
        }
    }

    [PSCustomObject]@{
        Files = $items
        Errors = $errors
        ErrorCount = $errorCount
        SkippedReparsePoints = $skippedReparsePoints
        SkippedReparsePointCount = $skippedReparsePointCount
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
            HumanSize = "0 B"
            CleanMethod = $Target.CleanMethod
            Risk = $Target.Risk
            SkippedReparsePointCount = 0
            SkippedReparsePoints = @()
            ErrorCount = 1
            Errors = @($Target.Reason)
        }
    }

    $scan = Get-CandidateFiles -Root $Target.ResolvedPath -Cutoff $Cutoff -Patterns $Target.Patterns -Recurse $Target.Recurse -UseAgeFilter $Target.UseAgeFilter
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
        CleanMethod = $Target.CleanMethod
        Risk = $Target.Risk
        SkippedReparsePointCount = $scan.SkippedReparsePointCount
        SkippedReparsePoints = @($scan.SkippedReparsePoints | Select-Object -Unique -First 20)
        ErrorCount = $scan.ErrorCount
        Errors = @($scan.Errors | Select-Object -Unique -First 50)
    }
}

function Remove-TargetFiles {
    param(
        [object]$Target,
        [datetime]$Cutoff
    )

    $scan = Get-CandidateFiles -Root $Target.ResolvedPath -Cutoff $Cutoff -Patterns $Target.Patterns -Recurse $Target.Recurse -UseAgeFilter $Target.UseAgeFilter
    $deletedBytes = [Int64]0
    $deletedCount = 0
    $errors = New-Object System.Collections.Generic.List[string]
    $deleteErrorCount = 0

    foreach ($file in $scan.Files) {
        if (-not (Test-UnderPath -Path $file.FullName -BasePath $Target.ResolvedPath)) {
            $deleteErrorCount += 1
            if ($errors.Count -lt 100) { $errors.Add("Refused outside allowlist: $($file.FullName)") | Out-Null }
            continue
        }

        try {
            $length = [Int64]$file.Length
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $deletedBytes += $length
            $deletedCount += 1
        } catch {
            $deleteErrorCount += 1
            if ($errors.Count -lt 100) { $errors.Add("$($file.FullName): $($_.Exception.Message)") | Out-Null }
        }
    }

    foreach ($err in $scan.Errors) {
        if ($errors.Count -lt 100) { $errors.Add($err) | Out-Null }
    }

    [PSCustomObject]@{
        Category = $Target.Category
        Path = $Target.Path
        DeletedFiles = $deletedCount
        DeletedBytes = $deletedBytes
        HumanDeleted = Convert-Bytes $deletedBytes
        SkippedReparsePointCount = $scan.SkippedReparsePointCount
        SkippedReparsePoints = @($scan.SkippedReparsePoints | Select-Object -Unique -First 20)
        ErrorCount = [int]($scan.ErrorCount + $deleteErrorCount)
        Errors = @($errors | Select-Object -Unique -First 100)
    }
}

function Invoke-ComponentCleanup {
    $dism = Join-Path $env:WINDIR "System32\dism.exe"
    if (-not (Test-Path -LiteralPath $dism)) {
        $dism = "dism.exe"
    }

    $output = @()
    $exitCode = $null

    try {
        $output = & $dism /Online /Cleanup-Image /StartComponentCleanup 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $output = @($_.Exception.Message)
        $exitCode = -1
    }

    [PSCustomObject]@{
        Requested = $true
        Command = "dism.exe /Online /Cleanup-Image /StartComponentCleanup"
        ExitCode = $exitCode
        Succeeded = ($exitCode -eq 0)
        OutputTail = @($output | Select-Object -Last 20 | ForEach-Object { "$_" })
    }
}

function Get-LargeFileHints {
    param([string]$DriveName)

    $userRoot = Join-Path (Get-DriveRoot -DriveName $DriveName) "Users"
    if (-not (Test-Path -LiteralPath $userRoot)) { return @() }

    $scan = Get-CandidateFiles -Root $userRoot -Cutoff ([datetime]::MinValue) -UseAgeFilter $false
    $scan.Files |
        Where-Object {
            $_.Length -ge 1GB -and
            $_.FullName -notmatch "\\AppData\\" -and
            $_.FullName -notmatch "\\OneDrive\\"
        } |
        Sort-Object Length -Descending |
        Select-Object -First 25 @{Name="Path";Expression={$_.FullName}},
            @{Name="Bytes";Expression={[Int64]$_.Length}},
            @{Name="HumanSize";Expression={Convert-Bytes ([Int64]$_.Length)}},
            LastWriteTime
}

$startedAt = Get-Date
$cutoff = (Get-Date).AddDays(-1 * $MinAgeDays)
$isAdmin = Test-IsAdministrator

if ($Mode -eq "Clean" -and -not $ConfirmClean) {
    throw "Cleanup mode requires -ConfirmClean. Run Audit first and get explicit user approval."
}

$before = Get-DriveSnapshot -DriveName $Drive
$targets = Get-CleanupTargets -DriveName $Drive
$measurements = @($targets | ForEach-Object { Measure-Target -Target $_ -Cutoff $cutoff })
$cleanupResults = @()
$recycleResult = $null
$componentCleanupResult = $null

if ($Mode -eq "Clean") {
    foreach ($target in $targets | Where-Object { $_.Enabled -and $_.Exists -and $null -ne $_.ResolvedPath -and $_.CleanMethod -eq "DeleteFiles" }) {
        $cleanupResults += Remove-TargetFiles -Target $target -Cutoff $cutoff
    }

    if ($IncludeRecycleBin) {
        try {
            Clear-RecycleBin -DriveLetter $Drive.TrimEnd(":") -Force -ErrorAction Stop
            $recycleResult = [PSCustomObject]@{
                Included = $true
                Cleared = $true
                Error = $null
            }
        } catch {
            $recycleResult = [PSCustomObject]@{
                Included = $true
                Cleared = $false
                Error = $_.Exception.Message
            }
        }
    }

    if ($RunComponentCleanup) {
        $componentCleanupResult = Invoke-ComponentCleanup
    }
}

if ($Mode -eq "Audit" -and $RunComponentCleanup) {
    $componentCleanupResult = [PSCustomObject]@{
        Requested = $true
        Command = "dism.exe /Online /Cleanup-Image /StartComponentCleanup"
        ExitCode = $null
        Succeeded = $null
        OutputTail = @("Audit only. Component cleanup would run only in Clean mode with -ConfirmClean.")
    }
}

$after = Get-DriveSnapshot -DriveName $Drive
$largeFiles = @()
if ($ScanLargeFiles) {
    $largeFiles = @(Get-LargeFileHints -DriveName $Drive)
}
$estimated = [Int64](($measurements | Where-Object { $_.Included } | Measure-Object -Property Bytes -Sum).Sum)
if ($null -eq $estimated) { $estimated = 0 }
$deleted = [Int64](($cleanupResults | Measure-Object -Property DeletedBytes -Sum).Sum)
if ($null -eq $deleted) { $deleted = 0 }
$actualFreeSpaceIncrease = [Int64]($after.FreeBytes - $before.FreeBytes)
$accountingDifference = [Int64]($actualFreeSpaceIncrease - $deleted)

$report = [PSCustomObject]@{
    StartedAt = $startedAt.ToString("o")
    FinishedAt = (Get-Date).ToString("o")
    Mode = $Mode
    Preset = $Preset
    Drive = $Drive
    MinAgeDays = $MinAgeDays
    IsAdministrator = [bool]$isAdmin
    IncludeBrowserCaches = [bool]$IncludeBrowserCaches
    IncludeRecycleBin = [bool]$IncludeRecycleBin
    IncludeWindowsUpdateCache = [bool]$IncludeWindowsUpdateCache
    IncludeDeliveryOptimizationCache = [bool]$IncludeDeliveryOptimizationCache
    IncludeErrorReports = [bool]$IncludeErrorReports
    IncludeThumbnailCache = [bool]$IncludeThumbnailCache
    IncludeShaderCaches = [bool]$IncludeShaderCaches
    IncludeDiagnosticDumps = [bool]$IncludeDiagnosticDumps
    IncludePackageManagerCaches = [bool]$IncludePackageManagerCaches
    IncludePipCache = [bool]$IncludePipCache
    IncludeNpmCache = [bool]$IncludeNpmCache
    IncludeUvCache = [bool]$IncludeUvCache
    IncludeNvidiaDownloadCache = [bool]$IncludeNvidiaDownloadCache
    IncludeInstallerTemp = [bool]$IncludeInstallerTemp
    ScanLargeFiles = [bool]$ScanLargeFiles
    RunComponentCleanup = [bool]$RunComponentCleanup
    FreeSpaceBefore = $before
    FreeSpaceAfter = $after
    EstimatedReclaimableBytes = $estimated
    EstimatedReclaimable = Convert-Bytes $estimated
    DeletedBytes = $deleted
    Deleted = Convert-Bytes $deleted
    ActualFreeSpaceIncreaseBytes = $actualFreeSpaceIncrease
    ActualFreeSpaceIncrease = Convert-Bytes $actualFreeSpaceIncrease
    AccountingDifferenceBytes = $accountingDifference
    AccountingDifference = Convert-Bytes $accountingDifference
    Targets = $measurements
    CleanupResults = $cleanupResults
    RecycleBin = $recycleResult
    ComponentCleanup = $componentCleanupResult
    LargeFileHints = $largeFiles
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
