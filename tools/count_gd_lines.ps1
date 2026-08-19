<#
.SYNOPSIS
    Totals the lines of .gd script in src/, in addons/, and in both combined.

.DESCRIPTION
    Sister script to list_gd_scripts.ps1. Where that one inventories every script
    and tracks conversion progress, this one only reports raw size.

.PARAMETER ProjectRoot
    Root of the Godot project. Defaults to the parent of this script's folder.

.PARAMETER Extension
    File extension to count. Defaults to .gd

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\count_gd_lines.ps1
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot,
    [string] $Extension = '.gd'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    [string] $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectRoot = Split-Path -Parent $scriptDirectory
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

# Directories never worth counting (engine cache, VCS metadata).
[string[]] $ExcludedDirectories = @('.godot', '.git', '.import')

if (-not $Extension.StartsWith('.')) { $Extension = ".$Extension" }

function Get-LineTotals {
    param([string] $Root)

    [int] $files = 0
    [int] $lines = 0

    if (Test-Path -LiteralPath $Root) {
        Get-ChildItem -LiteralPath $Root -Filter "*$Extension" -File -Recurse | ForEach-Object {
            [string] $relative = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
            [string[]] $segments = $relative -split '[\/]'

            foreach ($excluded in $ExcludedDirectories) {
                if ($segments -contains $excluded) { return }
            }

            [int] $fileLines = 0
            $reader = [System.IO.StreamReader]::new($_.FullName)
            try {
                while ($null -ne $reader.ReadLine()) { $fileLines++ }
            }
            finally {
                $reader.Dispose()
            }

            $files++
            $lines += $fileLines
        }
    }

    return [PSCustomObject]@{
        Root  = $Root
        Files = $files
        Lines = $lines
    }
}

[string] $srcRoot = Join-Path $ProjectRoot 'src'
[string] $addonsRoot = Join-Path $ProjectRoot 'addons'

if (-not (Test-Path -LiteralPath $srcRoot)) { Write-Warning "No src/ folder found under $ProjectRoot" }
if (-not (Test-Path -LiteralPath $addonsRoot)) { Write-Warning "No addons/ folder found under $ProjectRoot" }

$src = Get-LineTotals -Root $srcRoot
$addons = Get-LineTotals -Root $addonsRoot

[int] $combinedFiles = $src.Files + $addons.Files
[int] $combinedLines = $src.Lines + $addons.Lines

Write-Host "Counting *$Extension lines under $ProjectRoot..."
Write-Host ''
Write-Host ("{0,-10} {1,8} files {2,10} lines" -f 'src/', $src.Files, $src.Lines)
Write-Host ("{0,-10} {1,8} files {2,10} lines" -f 'addons/', $addons.Files, $addons.Lines)
Write-Host ("{0,-10} {1,8} files {2,10} lines" -f 'combined', $combinedFiles, $combinedLines)

[PSCustomObject]@{
    Src      = $src.Lines
    Addons   = $addons.Lines
    Combined = $combinedLines
}
