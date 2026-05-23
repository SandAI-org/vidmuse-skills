$ErrorActionPreference = "Stop"

$OssBaseUrl = if ($env:VIDMUSE_CLI_OSS_BASE_URL) { $env:VIDMUSE_CLI_OSS_BASE_URL } else { "https://vidmuse.sandcdn.com/cli" }
$OssBaseUrl = $OssBaseUrl.TrimEnd("/")
if (-not $OssBaseUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "VIDMUSE_CLI_OSS_BASE_URL must use https"
}
$VersionRequest = if ($env:VIDMUSE_CLI_VERSION) { $env:VIDMUSE_CLI_VERSION } else { "latest" }
$SkipChecksum = $env:VIDMUSE_CLI_SKIP_CHECKSUM -eq "1"

function Write-Log {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

function Get-InstallDir {
    if ($env:VIDMUSE_CLI_INSTALL_DIR) {
        return $env:VIDMUSE_CLI_INSTALL_DIR
    }

    $pathDir = Get-FirstWritablePathDir
    if ($pathDir) {
        return $pathDir
    }

    if ($env:LOCALAPPDATA) {
        return (Join-Path $env:LOCALAPPDATA "VidMuse\bin")
    }
    return (Join-Path $HOME ".local/bin")
}

function Test-WritableDirectory {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory) -or -not (Test-Path -Path $Directory -PathType Container)) {
        return $false
    }

    $probe = Join-Path $Directory ".vidmuse-write-test-$PID"
    try {
        [System.IO.File]::WriteAllText($probe, "")
        Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Test-PathContainsDir {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        return $false
    }

    try {
        $target = [System.IO.Path]::GetFullPath($Directory).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    } catch {
        return $false
    }

    foreach ($entry in ($env:PATH -split [System.IO.Path]::PathSeparator)) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }
        try {
            $normalized = [System.IO.Path]::GetFullPath($entry).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            if ($normalized -eq $target) {
                return $true
            }
        } catch {
        }
    }

    return $false
}

function Get-FirstWritablePathDir {
    $existing = Get-Command vidmuse -ErrorAction SilentlyContinue
    if ($existing) {
        $existingDir = Split-Path -Parent $existing.Source
        if (Test-WritableDirectory -Directory $existingDir) {
            return $existingDir
        }
    }

    foreach ($entry in ($env:PATH -split [System.IO.Path]::PathSeparator)) {
        if ([string]::IsNullOrWhiteSpace($entry) -or -not [System.IO.Path]::IsPathRooted($entry)) {
            continue
        }
        if (Test-WritableDirectory -Directory $entry) {
            return $entry
        }
    }

    return $null
}

function Invoke-Download {
    param(
        [string]$Url,
        [string]$Destination
    )
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

function Get-Platform {
    $description = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    if ($description -match "Windows") {
        return "windows"
    }
    if ($description -match "Darwin") {
        return "darwin"
    }
    if ($description -match "Linux") {
        return "linux"
    }
    throw "unsupported OS: $description"
}

function Get-Arch {
    switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()) {
        "x64" { return "amd64" }
        "arm64" { return "arm64" }
        default { throw "unsupported architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)" }
    }
}

function Resolve-LatestVersion {
    $manifestPath = New-TemporaryFile
    try {
        Invoke-Download -Url "$OssBaseUrl/latest.json" -Destination $manifestPath
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.version) {
            return $manifest.version
        }
    } catch {
        throw "could not resolve latest VidMuse CLI version from release CDN"
    }

    throw "could not resolve latest VidMuse CLI version from release CDN"
}

function Get-AssetName {
    param(
        [string]$OsName,
        [string]$ArchName
    )
    $Base = "vidmuse-$OsName-$ArchName"
    if ($OsName -eq "darwin") {
        return "$Base.zip"
    }
    if ($OsName -eq "windows") {
        return "$Base.exe"
    }
    return $Base
}

function Get-BinaryName {
    param(
        [string]$OsName,
        [string]$ArchName
    )
    if ($OsName -eq "windows") {
        return "vidmuse-$OsName-$ArchName.exe"
    }
    return "vidmuse-$OsName-$ArchName"
}

function Test-Checksum {
    param(
        [string]$FilePath,
        [string]$AssetName,
        [string]$ChecksumsPath
    )

    if ($SkipChecksum) {
        Write-Log "checksum verification skipped by VIDMUSE_CLI_SKIP_CHECKSUM=1"
        return
    }

    $expected = $null
    foreach ($line in Get-Content $ChecksumsPath) {
        $parts = $line -split "\s+"
        if ($parts.Length -ge 2 -and $parts[1] -eq $AssetName) {
            $expected = $parts[0]
            break
        }
    }

    if (-not $expected) {
        throw "checksum for $AssetName was not found"
    }

    $actual = (Get-FileHash -Algorithm SHA256 -Path $FilePath).Hash.ToLowerInvariant()
    if ($actual -ne $expected.ToLowerInvariant()) {
        throw "checksum mismatch for $AssetName"
    }
}

function Install-Asset {
    param(
        [string]$AssetPath,
        [string]$AssetName,
        [string]$BinaryName,
        [string]$TargetPath
    )

    $source = $AssetPath
    if ($AssetName.EndsWith(".zip")) {
        $extractDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
        Expand-Archive -Path $AssetPath -DestinationPath $extractDir -Force
        $found = Get-ChildItem -Path $extractDir -Recurse -File -Filter $BinaryName | Select-Object -First 1
        if (-not $found) {
            throw "archive did not contain $BinaryName"
        }
        $source = $found.FullName
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TargetPath) | Out-Null
    Copy-Item -Path $source -Destination $TargetPath -Force
    if ($OsName -ne "windows") {
        & chmod 0755 $TargetPath
    }
}

$OsName = Get-Platform
$ArchName = Get-Arch
$Version = if ($VersionRequest -eq "latest") { Resolve-LatestVersion } else { $VersionRequest }
$AssetName = Get-AssetName -OsName $OsName -ArchName $ArchName
$BinaryName = Get-BinaryName -OsName $OsName -ArchName $ArchName
$InstallDir = Get-InstallDir
$TargetName = if ($OsName -eq "windows") { "vidmuse.exe" } else { "vidmuse" }
$TargetPath = Join-Path $InstallDir $TargetName
$ReleaseBase = "$OssBaseUrl/releases/$Version"
$AssetPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
$ChecksumsPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))

Write-Log "installing VidMuse CLI $Version for $OsName/$ArchName"

Invoke-Download -Url "$ReleaseBase/$AssetName" -Destination $AssetPath
Invoke-Download -Url "$ReleaseBase/checksums.txt" -Destination $ChecksumsPath

Test-Checksum -FilePath $AssetPath -AssetName $AssetName -ChecksumsPath $ChecksumsPath
Install-Asset -AssetPath $AssetPath -AssetName $AssetName -BinaryName $BinaryName -TargetPath $TargetPath

Write-Log "installed VidMuse CLI to $TargetPath"
if (-not (Test-PathContainsDir -Directory (Split-Path -Parent $TargetPath))) {
    Write-Log "warning: $(Split-Path -Parent $TargetPath) is not on PATH; add it to PATH to run vidmuse directly"
}
try {
    & $TargetPath --version 1>&2
} catch {
    Write-Log "warning: could not read vidmuse CLI version from $TargetPath"
}
Write-Output $TargetPath
