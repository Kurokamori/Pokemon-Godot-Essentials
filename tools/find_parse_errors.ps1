<#
.SYNOPSIS
    Collects GDScript parse errors for the project and ranks the missing
    identifiers / types by how many times they are referenced.

.DESCRIPTION
    Parses every .gd script in the project with a headless Godot
    (--check-only, one file at a time, so nothing is skipped), or optionally
    does a single fast editor scan, or re-reads a previously captured log.
    The resulting errors are grouped by the symbol that could not be resolved.

    The ranked list answers "which missing class would fix the most errors if I
    implemented it next". The window stays open until a key is pressed so the
    terminal can be left up as a running counter.

.PARAMETER ProjectRoot
    Root of the Godot project. Defaults to the parent of this script's folder.

.PARAMETER GodotPath
    Full path to the Godot executable. If omitted the script looks at the GODOT
    environment variable, then PATH, then common install locations (including
    the C:\Godot fallback).

.PARAMETER EditorScan
    Use a single headless editor run instead of the per-file check. Much faster
    but only reports scripts the editor happens to touch, so it under-counts.

.PARAMETER ScriptRoots
    Folders (relative to the project root) to scan in per-file mode.
    Defaults to src, game, scenes, tools and addons.

.PARAMETER IncludeAutoloads
    Keep errors about project autoload singletons. They are filtered out by
    default because --check-only parses a script without the autoload table,
    so those are false positives rather than missing classes.

.PARAMETER CountRepeats
    Count every duplicate error line. By default identical errors at the same
    file and line are collapsed so the ranking reflects distinct call sites.

.PARAMETER LogFile
    Parse this existing log file instead of launching Godot.

.PARAMETER SaveLog
    Write the raw captured Godot output to this path.

.PARAMETER Top
    How many ranked symbols to print. 0 means all. Defaults to 0.

.PARAMETER ShowFiles
    Also list the files (and line numbers) referencing each missing symbol.

.PARAMETER NoWait
    Do not wait for a key press before exiting.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\find_parse_errors.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\find_parse_errors.ps1 -ShowFiles -Top 25
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot,
    [string] $GodotPath,
    [switch] $EditorScan,
    [string[]] $ScriptRoots = @('src', 'game', 'scenes', 'tools', 'addons'),
    [switch] $IncludeAutoloads,
    [switch] $CountRepeats,
    [string] $LogFile,
    [string] $SaveLog,
    [int]    $Top = 0,
    [switch] $ShowFiles,
    [switch] $NoWait
)

$ErrorActionPreference = 'Stop'

function Resolve-ProjectRoot {
    param([string] $Candidate, [string] $ScriptDirectory)
    if (-not [string]::IsNullOrWhiteSpace($Candidate)) { return (Resolve-Path $Candidate).Path }
    return (Resolve-Path (Split-Path -Parent $ScriptDirectory)).Path
}

function Resolve-GodotExecutable {
    param([string] $Candidate)

    if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
        if (Test-Path $Candidate) { return (Resolve-Path $Candidate).Path }
        throw "Godot executable not found at '$Candidate'."
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GODOT) -and (Test-Path $env:GODOT)) {
        return (Resolve-Path $env:GODOT).Path
    }

    foreach ($name in @('godot', 'godot4', 'Godot_v4', 'Godot')) {
        try {
            $command = Get-Command $name -ErrorAction Stop
            if ($null -ne $command -and $command.Source) { return $command.Source }
        } catch { }
    }

    [string[]] $searchRoots = @(
        'C:\Godot',
        "$env:ProgramFiles\Godot",
        "${env:ProgramFiles(x86)}\Godot",
        "$env:LOCALAPPDATA\Programs\Godot",
        "$env:LOCALAPPDATA\Programs",
        "$env:USERPROFILE\scoop\apps\godot",
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Desktop"
    )

    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) { continue }
        try {
            $candidates = Get-ChildItem -Path $root -Filter 'Godot*.exe' -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending
            if ($null -eq $candidates) { continue }

            $found = $candidates | Where-Object { $_.Name -like '*console*' } | Select-Object -First 1
            if ($null -eq $found) { $found = $candidates | Select-Object -First 1 }
            if ($null -ne $found) { return $found.FullName }
        } catch { }
    }

    throw "Could not locate a Godot executable. Pass -GodotPath, or set the GODOT environment variable, or use -LogFile."
}

function Invoke-GodotParseRun {
    param([string] $Executable, [string] $Root)

    Write-Host "Running Godot headlessly to parse the project..." -ForegroundColor DarkGray
    Write-Host "  $Executable" -ForegroundColor DarkGray

    [string] $stdoutPath = [System.IO.Path]::GetTempFileName()
    [string] $stderrPath = [System.IO.Path]::GetTempFileName()

    [string[]] $arguments = @(
        '--headless',
        '--path', $Root,
        '--editor',
        '--quit-after', '600'
    )

    $process = Start-Process -FilePath $Executable -ArgumentList $arguments -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

    [string[]] $lines = @()
    if (Test-Path $stdoutPath) { $lines += Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue }
    if (Test-Path $stderrPath) { $lines += Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue }

    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

    if ($lines.Count -eq 0) {
        Write-Host "Godot produced no output (exit code $($process.ExitCode))." -ForegroundColor Yellow
    }

    return $lines
}

function Get-AutoloadNames {
    param([string] $Root)

    [string] $projectFile = Join-Path $Root 'project.godot'
    if (-not (Test-Path $projectFile)) { return @() }

    [string[]] $names = @()
    [bool] $inSection = $false

    foreach ($line in (Get-Content -LiteralPath $projectFile)) {
        [string] $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $inSection = ($Matches[1] -eq 'autoload')
            continue
        }
        if (-not $inSection) { continue }
        if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=') { $names += $Matches[1] }
    }

    return $names
}

function Invoke-GodotPerFileRun {
    param([string] $Executable, [string] $Root, [string[]] $Roots)

    [System.Collections.Generic.List[string]] $files = New-Object 'System.Collections.Generic.List[string]'
    foreach ($relative in $Roots) {
        [string] $folder = Join-Path $Root $relative
        if (-not (Test-Path $folder)) { continue }
        foreach ($file in (Get-ChildItem -Path $folder -Filter '*.gd' -Recurse -File -ErrorAction SilentlyContinue)) {
            $files.Add($file.FullName)
        }
    }

    if ($files.Count -eq 0) { throw "No .gd files found under: $($Roots -join ', ')" }

    Write-Host ("Parsing {0} scripts with {1}..." -f $files.Count, $Executable) -ForegroundColor DarkGray

    [System.Collections.Generic.List[string]] $lines = New-Object 'System.Collections.Generic.List[string]'
    [int] $index = 0

    foreach ($file in $files) {
        $index++
        Write-Progress -Activity 'Parsing GDScript' -Status "$index / $($files.Count)  $file" `
            -PercentComplete ([int](100 * $index / $files.Count))

        [string] $stdoutPath = [System.IO.Path]::GetTempFileName()
        [string] $stderrPath = [System.IO.Path]::GetTempFileName()

        [string[]] $arguments = @('--headless', '--path', $Root, '--check-only', '--script', $file)

        [void] (Start-Process -FilePath $Executable -ArgumentList $arguments -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath)

        foreach ($path in @($stdoutPath, $stderrPath)) {
            if (-not (Test-Path $path)) { continue }
            foreach ($line in (Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)) { $lines.Add($line) }
        }

        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }

    Write-Progress -Activity 'Parsing GDScript' -Completed
    return $lines.ToArray()
}

function Get-ParseErrorRecords {
    param([string[]] $Lines)

    $patterns = @(
        @{ Kind = 'Identifier not found';   Regex = 'Identifier\s+"([^"]+)"\s+not\s+declared\s+in\s+the\s+current\s+scope' },
        @{ Kind = 'Identifier not found';   Regex = 'Identifier\s+not\s+found:\s*"?([A-Za-z_][A-Za-z0-9_]*)"?' },
        @{ Kind = 'Identifier not found';   Regex = 'Identifier\s+"([^"]+)"\s+not\s+found' },
        @{ Kind = 'Type not found';         Regex = 'Could\s+not\s+find\s+type\s+"([^"]+)"' },
        @{ Kind = 'Type not found';         Regex = 'Cannot\s+find\s+type\s+"([^"]+)"' },
        @{ Kind = 'Class not found';        Regex = 'Class\s+"([^"]+)"\s+(?:could\s+not\s+be\s+found|was\s+not\s+found)' },
        @{ Kind = 'Autoload/global missing';Regex = 'Autoload\s+"([^"]+)"' },
        @{ Kind = 'Function not found';     Regex = 'Function\s+"([^"]+)"\s+not\s+found' },
        @{ Kind = 'Member not found';       Regex = 'Cannot\s+find\s+(?:member|property)\s+"([^"]+)"' },
        @{ Kind = 'Missing script/resource';Regex = 'Failed\s+loading\s+resource:\s*(res://\S+)' },
        @{ Kind = 'Missing script/resource';Regex = 'No\s+loader\s+found\s+for\s+resource:\s*(res://\S+)' }
    )

    $patterns += @{ Kind = 'External member not resolved'; Regex = 'Could\s+not\s+resolve\s+external\s+class\s+member\s+"([^"]+)"' }

    [System.Collections.ArrayList] $records = New-Object System.Collections.ArrayList
    [System.Collections.ArrayList] $pending = New-Object System.Collections.ArrayList

    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $location = [regex]::Match($line, '^\s*at:.*\((res://[^\s:)]+):(\d+)\)')
        if ($location.Success) {
            foreach ($record in $pending) {
                $record.File = $location.Groups[1].Value
                $record.Line = [int] $location.Groups[2].Value
            }
            $pending.Clear()
            continue
        }

        foreach ($pattern in $patterns) {
            $match = [regex]::Match($line, $pattern.Regex, 'IgnoreCase')
            if (-not $match.Success) { continue }

            [string] $symbol = $match.Groups[1].Value.TrimEnd('.', ',', ')', '"')
            if ($symbol.EndsWith('()')) { $symbol = $symbol.Substring(0, $symbol.Length - 2) }

            $record = [pscustomobject] @{
                Kind   = $pattern.Kind
                Symbol = $symbol
                File   = ''
                Line   = 0
                Raw    = $line.Trim()
            }
            [void] $records.Add($record)
            [void] $pending.Add($record)
            break
        }
    }

    return $records
}

function Write-Report {
    param([object[]] $Records, [int] $TopCount, [bool] $IncludeFiles, [bool] $KeepRepeats)

    if ($Records.Count -eq 0) {
        Write-Host ""
        Write-Host "No parse errors matched the known patterns." -ForegroundColor Green
        return
    }

    if (-not $KeepRepeats) {
        $Records = @($Records | Sort-Object Kind, Symbol, File, Line -Unique)
    }

    $groups = $Records |
        Group-Object -Property Symbol |
        Sort-Object Count -Descending

    if ($TopCount -gt 0) { $groups = $groups | Select-Object -First $TopCount }

    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor DarkGray
    Write-Host " PARSE ERRORS BY MISSING SYMBOL (most impactful first)" -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("{0,6}  {1,-26}  {2,-24}  {3}" -f 'COUNT', 'SYMBOL', 'KIND', 'FILES') -ForegroundColor DarkGray
    Write-Host ("{0,6}  {1,-26}  {2,-24}  {3}" -f '-----', '--------------------------', '------------------------', '-----') -ForegroundColor DarkGray

    foreach ($group in $groups) {
        [string] $kinds = ($group.Group | Select-Object -ExpandProperty Kind -Unique) -join ', '
        [int] $fileCount = ($group.Group | Select-Object -ExpandProperty File -Unique | Where-Object { $_ }).Count

        $color = 'White'
        if ($group.Count -ge 20) { $color = 'Red' }
        elseif ($group.Count -ge 5) { $color = 'Yellow' }

        Write-Host ("{0,6}  {1,-26}  {2,-24}  {3}" -f $group.Count, $group.Name, $kinds, $fileCount) -ForegroundColor $color

        if ($IncludeFiles) {
            $locations = $group.Group |
                Where-Object { $_.File } |
                Sort-Object File, Line -Unique
            foreach ($location in $locations) {
                Write-Host ("        {0}:{1}" -f $location.File, $location.Line) -ForegroundColor DarkGray
            }
        }
    }

    $byKind = $Records | Group-Object Kind | Sort-Object Count -Descending

    Write-Host ""
    Write-Host ("-" * 78) -ForegroundColor DarkGray
    Write-Host " TOTALS BY ERROR KIND" -ForegroundColor Cyan
    Write-Host ("-" * 78) -ForegroundColor DarkGray
    foreach ($kind in $byKind) {
        Write-Host ("{0,6}  {1}" -f $kind.Count, $kind.Name)
    }

    Write-Host ""
    Write-Host ("{0,6}  total errors" -f $Records.Count) -ForegroundColor Cyan
    Write-Host ("{0,6}  distinct missing symbols" -f ($Records | Group-Object -Property Symbol).Count) -ForegroundColor Cyan
    Write-Host ("{0,6}  affected files" -f ($Records | Select-Object -ExpandProperty File -Unique | Where-Object { $_ }).Count) -ForegroundColor Cyan
}

[string] $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-ProjectRoot -Candidate $ProjectRoot -ScriptDirectory $scriptDirectory

Write-Host ""
Write-Host "Project: $ProjectRoot" -ForegroundColor DarkGray

[string[]] $outputLines = @()

if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
    if (-not (Test-Path $LogFile)) { throw "Log file not found: $LogFile" }
    Write-Host "Reading log: $LogFile" -ForegroundColor DarkGray
    $outputLines = Get-Content -LiteralPath $LogFile
} else {
    [string] $executable = Resolve-GodotExecutable -Candidate $GodotPath
    if ($EditorScan) {
        $outputLines = Invoke-GodotParseRun -Executable $executable -Root $ProjectRoot
    } else {
        $outputLines = Invoke-GodotPerFileRun -Executable $executable -Root $ProjectRoot -Roots $ScriptRoots
    }
}

if (-not [string]::IsNullOrWhiteSpace($SaveLog)) {
    $outputLines | Out-File -FilePath $SaveLog -Encoding utf8
    Write-Host "Raw output saved to: $SaveLog" -ForegroundColor DarkGray
}

$parseRecords = Get-ParseErrorRecords -Lines $outputLines

if (-not $IncludeAutoloads) {
    [string[]] $autoloads = Get-AutoloadNames -Root $ProjectRoot
    if ($autoloads.Count -gt 0) {
        [int] $before = @($parseRecords).Count
        $parseRecords = @($parseRecords | Where-Object { $autoloads -notcontains $_.Symbol })
        [int] $filtered = $before - @($parseRecords).Count
        if ($filtered -gt 0) {
            Write-Host ("Filtered {0} autoload false positives ({1}). Use -IncludeAutoloads to keep them." -f $filtered, ($autoloads -join ', ')) -ForegroundColor DarkGray
        }
    }
}
Write-Report -Records @($parseRecords) -TopCount $Top -IncludeFiles ([bool] $ShowFiles) -KeepRepeats ([bool] $CountRepeats)

if (-not $NoWait) {
    Write-Host ""
    Write-Host "Press any key to close..." -ForegroundColor DarkGray
    try {
        [void] $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    } catch {
        [void] (Read-Host)
    }
}
