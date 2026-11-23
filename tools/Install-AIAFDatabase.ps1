#Requires -Version 5.1
<#
.SYNOPSIS
    Lab-only, fresh-install deployment of AIAF into a DBA-provisioned database.
.DESCRIPTION
    Runs Test-AIAFDatabase.ps1 in a separate PowerShell process and refuses to
    deploy unless it passes. Executes repository SQL files in numbered folder
    order using sqlcmd. Stops on the first failed file. Does not create, drop,
    or change database settings. Includes synthetic data and test principals.
.EXAMPLE
    .\tools\Install-AIAFDatabase.ps1 -ServerInstance 'btg-kwilkie' -Database 'AIAF_DeploymentTest' -TrustServerCertificate -LabMode
.NOTES
    This is NOT an upgrade or production installer. After a partial failure,
    inspect the target database; do not rerun against it automatically.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerInstance,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Database,

    [Parameter(Mandatory = $true)]
    [switch]$LabMode,

    [switch]$TrustServerCertificate
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sqlRoot = Join-Path $repoRoot 'sql'
$preflight = Join-Path $PSScriptRoot 'Test-AIAFDatabase.ps1'
$stages = @(
    '00_setup',
    '01_schema',
    '02_reference_data',
    '03_constraints',
    '04_indexes',
    '05_views',
    '06_procedures',
    '07_security',
    '08_seed',
    '90_validation'
)

# Use an explicit set of stage directories; never sweep arbitrary directories.
$files = @()
foreach ($stage in $stages) {
    $stagePath = Join-Path $sqlRoot $stage
    if (-not (Test-Path -LiteralPath $stagePath -PathType Container)) {
        throw "Missing SQL stage: $stagePath"
    }
    $stageFiles = @(Get-ChildItem -LiteralPath $stagePath -Filter '*.sql' -File | Sort-Object Name)
    if ($stageFiles.Count -eq 0) {
        throw "No SQL scripts found in stage: $stage"
    }
    $files += $stageFiles
}

if (-not (Test-Path -LiteralPath $preflight -PathType Leaf)) {
    throw "Preflight script missing: $preflight"
}
if (-not (Get-Command sqlcmd.exe -ErrorAction SilentlyContinue)) {
    throw 'sqlcmd.exe not found on PATH.'
}

# Launch a child PowerShell process so an `exit` in preflight cannot terminate
# this installer and so the preflight exit code is unambiguous.
$powerShellExe = (Get-Process -Id $PID).Path
if (-not $powerShellExe) { throw 'Could not locate the current PowerShell executable.' }

$preflightArgs = @('-NoProfile', '-NonInteractive', '-File', $preflight,
                   '-ServerInstance', $ServerInstance, '-Database', $Database)
if ($TrustServerCertificate) { $preflightArgs += '-TrustServerCertificate' }

Write-Host "AIAF LAB deployment target: $ServerInstance / $Database" -ForegroundColor Cyan
Write-Host 'Running read-only database preflight...' -ForegroundColor Cyan
& $powerShellExe @preflightArgs
$preflightExitCode = $LASTEXITCODE
if ($preflightExitCode -ne 0) {
    Write-Error "Preflight rejected deployment (exit code $preflightExitCode). No SQL deployment scripts were run."
    exit 1
}

Write-Host "Preflight passed. Starting $($files.Count) SQL scripts." -ForegroundColor Green
$completed = 0
foreach ($file in $files) {
    $relative = $file.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
    Write-Host ('[{0}/{1}] {2}' -f ($completed + 1), $files.Count, $relative)

    # -d targets the existing database; -b makes SQL errors fail the process;
    # -V 11 sets the severity threshold; -r 1 directs SQL errors to stderr.
    # -X disables sqlcmd scripting variables and environment startup scripts.
    $sqlcmdArgs = @('-S', $ServerInstance, '-d', $Database, '-E', '-b', '-V', '11',
                    '-r', '1', '-X', '-I', '-i', $file.FullName)
    if ($TrustServerCertificate) { $sqlcmdArgs += '-C' }

    & sqlcmd.exe @sqlcmdArgs
    $sqlExitCode = $LASTEXITCODE
    if ($sqlExitCode -ne 0) {
        Write-Host "DEPLOYMENT FAILED at $relative (sqlcmd exit code $sqlExitCode)." -ForegroundColor Red
        Write-Host "$completed scripts completed successfully; database may be partially deployed." -ForegroundColor Yellow
        Write-Host 'Do not rerun this fresh-install script against the partially deployed database.' -ForegroundColor Yellow
        exit 1
    }
    $completed++
}

Write-Host "AIAF LAB DEPLOYMENT COMPLETE: $completed/$($files.Count) SQL scripts succeeded." -ForegroundColor Green
Write-Host 'Next: configure Python to use this database and run the 17 integration scenarios.'
exit 0
