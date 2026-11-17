# ApexDrama version bump helper (ASCII only: PowerShell 5.1 misreads
# BOM-less UTF-8 as ANSI).
#
# Version scheme
#   version: <major>.<minor>.<patch>+<versionCode>
#   versionCode = major*100 + minor*10 + patch
#   e.g. 1.1.1 -> 111, 1.1.2 -> 112, 1.2.0 -> 120, 1.12.0 -> 220
#
# Invariant: patch stays a single digit (0-9). Bumping past 9 rolls over to
# the next minor (1.1.9 -> 1.2.0), so the versionCode slots never overlap.
# With that invariant the encoding is unambiguous even when minor is 2 digits.
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File tool\bump_version.ps1
#       -> bumps patch: 1.1.2 -> 1.1.3 (build 113); 1.1.9 -> 1.2.0 (build 120)
#   powershell -ExecutionPolicy Bypass -File tool\bump_version.ps1 -Version 1.2.0
#       -> sets explicit version, build number still derived

param(
    [string]$Version
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"

$content = [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8)
$match = [regex]::Match($content, '(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+[0-9]+)?')
if (-not $match.Success) { throw "Cannot parse version from pubspec.yaml" }

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value

if ($Version) {
    $vm = [regex]::Match($Version, '^([0-9]+)\.([0-9]+)\.([0-9])$')
    if (-not $vm.Success) {
        throw "-Version must look like 1.2.0 with a single-digit patch (0-9)"
    }
    $major = [int]$vm.Groups[1].Value
    $minor = [int]$vm.Groups[2].Value
    $patch = [int]$vm.Groups[3].Value
}
else {
    # Single-digit patch invariant: 1.1.9 -> 1.2.0, never 1.1.10.
    $patch++
    if ($patch -gt 9) {
        $patch = 0
        $minor++
        if ($minor -gt 99) {
            $minor = 0
            $major++
        }
    }
}

$name = "$major.$minor.$patch"
$code = $major * 100 + $minor * 10 + $patch
$newLine = "version: $name+$code"

# Replace the whole version line, keeping the rest of the file untouched.
$updated = [regex]::Replace(
    $content,
    '(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?',
    $newLine
)
# Write back with LF endings and no BOM, matching the existing file.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pubspecPath, $updated, $utf8NoBom)

Write-Host "==> Version: $name  (versionCode $code)"
