# ApexDrama Windows packaging script (ASCII only: PowerShell 5.1
# misreads BOM-less UTF-8 as ANSI).
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1
# Outputs (dist/):
#   ApexDrama-<version>-windows-x64.zip         portable, extract & run
#   ApexDrama-<version>-windows-x64-setup.exe   installer (Inno Setup, optional)
# Version comes from pubspec.yaml `version:` (1.0.2+3 -> 1.0.2).
# Asset naming matches update_service's Windows filter (contains windows-x64).

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    # 1. Version (three segments; build number stays out of filenames)
    $pubspec = (Get-Content (Join-Path $repoRoot "pubspec.yaml")) -join "`n"
    $version = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)').Groups[1].Value
    if (-not $version) { throw "Cannot parse version from pubspec.yaml" }
    Write-Host "==> Packaging ApexDrama v$version"

    # 2. Release build
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
    $releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"

    # 3. Portable zip (whole folder: exe + dll + data, all required)
    New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot "dist") | Out-Null
    $zipPath = Join-Path $repoRoot "dist\ApexDrama-$version-windows-x64.zip"
    Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $zipPath -Force
    $zipMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Host "==> Portable zip: $zipPath ($zipMB MB)"

    # 4. Inno Setup installer (skipped with a warning if ISCC is absent)
    $isccCandidates = @(
        "..\.tooling\InnoSetup6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )
    $iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($iscc) {
        $isccFull = if ([System.IO.Path]::IsPathRooted($iscc)) { $iscc } else { Join-Path $repoRoot $iscc }
        & $isccFull "/DAppVersion=$version" (Join-Path $repoRoot "tool\windows_installer.iss")
        if ($LASTEXITCODE -ne 0) { throw "ISCC installer build failed" }
        Write-Host "==> Installer: dist\ApexDrama-$version-windows-x64-setup.exe"
    } else {
        Write-Warning "Inno Setup 6 (ISCC.exe) not found; skip installer, zip only"
    }
} finally {
    Pop-Location
}
