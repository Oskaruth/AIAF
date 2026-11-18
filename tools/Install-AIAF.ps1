<#
.SYNOPSIS
    Installs the AI Interaction Audit Framework (AIAF).

.DESCRIPTION
    Performs a fresh AIAF database installation using
    a manifest-driven deployment sequence.

    Installation modes:
        Core            Framework without synthetic data
        Demo            Framework with synthetic data
        IntegrationTest Complete laboratory environment

    The target database must already exist.

    Existing AIAF installations are not modified.
    Failed installations are not automatically removed.

.EXAMPLE
    .\tools\Install-AIAF.ps1 `
        -ServerInstance localhost `
        -DatabaseName AIAF `
        -Mode Core

.EXAMPLE
    .\tools\Install-AIAF.ps1 `
        -ServerInstance localhost `
        -DatabaseName AIAF_Test `
        -Mode IntegrationTest `
        -TrustServerCertificate `
        -PlanOnly
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ServerInstance,

    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,

    [ValidateSet('Core', 'Demo', 'IntegrationTest')]
    [string]$Mode = 'Core',

    [switch]$TrustServerCertificate,

    [switch]$PlanOnly,

    [ValidateRange(1, 86400)]
    [int]$QueryTimeout = 300,

    [string]$LogDirectory
)

$ErrorActionPreference = 'Stop'

# =====================================================
# Resolve installation paths
# =====================================================

$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$SqlRoot = Join-Path $RepositoryRoot 'sql'
$ManifestPath = Join-Path $PSScriptRoot 'AIAF.Deployment.psd1'
$PreflightPath = Join-Path $PSScriptRoot 'AIAF.Preflight.ps1'
$ConnectionPath = Join-Path $PSScriptRoot 'AIAF.Connection.ps1'
$ExecutionPath = Join-Path $PSScriptRoot 'AIAF.SqlExecution.ps1'

if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
    $LogDirectory = Join-Path $RepositoryRoot 'logs'
}

# =====================================================
# Load manifest and validate runtime requirements
# =====================================================

$Manifest = Import-PowerShellDataFile -Path $ManifestPath
$MinimumPowerShellVersion = [version]$Manifest.MinimumPowerShellVersion
$MinimumSqlServerModuleVersion = [version]$Manifest.MinimumSqlServerModuleVersion

if ($PSVersionTable.PSVersion -lt $MinimumPowerShellVersion) {
    throw "PowerShell $MinimumPowerShellVersion or later is required. Current: $($PSVersionTable.PSVersion)."
}
if (Get-Module -Name SQLPS) {
    throw 'The legacy SQLPS module is loaded. Start a new PowerShell session.'
}

Import-Module SqlServer -MinimumVersion $MinimumSqlServerModuleVersion -ErrorAction Stop
$LoadedModule = Get-Module -Name SqlServer | Sort-Object Version -Descending | Select-Object -First 1
$SqlServerModuleVersion = $LoadedModule.Version
if ($SqlServerModuleVersion -lt $MinimumSqlServerModuleVersion) {
    throw "SqlServer module $MinimumSqlServerModuleVersion or later is required. Loaded: $SqlServerModuleVersion."
}

. $ConnectionPath
. $ExecutionPath
. $PreflightPath

# Force dependency discovery before any database connection is made.
$Parser = New-AIAFSqlParser

# =====================================================
# Build and validate deployment plan
# =====================================================

$AllScripts = @(
    $Manifest.Phases |
        ForEach-Object { $_.Scripts }
)

$ActualScripts = @(
    Get-ChildItem $SqlRoot -Recurse -File -Filter *.sql |
        ForEach-Object {
            $_.FullName.Substring($SqlRoot.Length + 1)
        }
)

$MissingScripts = @(
    $AllScripts |
        Where-Object {
            -not (Test-Path -LiteralPath (
                Join-Path $SqlRoot $_
            ) -PathType Leaf)
        }
)

$UnlistedScripts = @(
    $ActualScripts |
        Where-Object { $_ -notin $AllScripts }
)

$DuplicateScripts = @(
    $AllScripts |
        Group-Object |
        Where-Object { $_.Count -gt 1 }
)

if (
    $MissingScripts.Count -gt 0 -or
    $UnlistedScripts.Count -gt 0 -or
    $DuplicateScripts.Count -gt 0
) {
    throw 'Deployment manifest inventory validation failed.'
}

$SelectedPhases = @(
    $Manifest.Phases |
        Where-Object { $Mode -in $_.Modes }
)

$DeploymentPlan = @(
    foreach ($Phase in $SelectedPhases) {
        foreach ($Script in $Phase.Scripts) {
            [PSCustomObject]@{
                Phase = $Phase.Name
                Script = $Script
                FullPath = Join-Path $SqlRoot $Script
            }
        }
    }
)

if ($DeploymentPlan.Count -eq 0) {
    throw 'No deployment scripts were selected.'
}

# =====================================================
# Display installation configuration
# =====================================================

Write-Host ''
Write-Host '========================================'
Write-Host ' AIAF Database Installer'
Write-Host '========================================'
Write-Host "Server:            $ServerInstance"
Write-Host "Database:          $DatabaseName"
Write-Host "Mode:              $Mode"
Write-Host "Manifest version:  $($Manifest.ManifestVersion)"
Write-Host "Phases:            $($SelectedPhases.Count)"
Write-Host "Scripts:           $($DeploymentPlan.Count)"
Write-Host "Plan only:         $($PlanOnly.IsPresent)"
Write-Host "PowerShell:        $($PSVersionTable.PSVersion)"
Write-Host "SqlServer module:  $SqlServerModuleVersion"
Write-Host 'SQL encryption:    Mandatory'
Write-Host "Trust certificate: $($TrustServerCertificate.IsPresent)"

if ($TrustServerCertificate.IsPresent) {
    Write-Warning ('Server certificate validation is disabled. ' +
        'The connection is encrypted, but server identity is not independently verified.')
}
Write-Host ''

# =====================================================
# Initialize execution state and audit log
# =====================================================

$InstallationId = [Guid]::NewGuid().ToString()
$InstallationStartedAt = [DateTime]::UtcNow
$InstallationResults = [System.Collections.Generic.List[object]]::new()
$InstallationStatus = 'RUNNING'
$InstallationError = $null
$Preflight = $null
$ConnectionValidation = $null
$Connection = $null
$LockAcquired = $false
$LockReleaseResult = $null
$CleanupError = $null
$LogFile = $null
$LogError = $null
$PreparedScripts = [System.Collections.Generic.List[object]]::new()

# Settings are executed on the same locked session before EACH deployment script.
# They are not concatenated to the original SQL file content.
$SessionSettings = @'
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
'@

try {
    New-Item -ItemType Directory -Force -Path $LogDirectory -ErrorAction Stop | Out-Null
    $LogFile = Join-Path $LogDirectory (
        'AIAF_Install_{0}_{1}.json' -f
        (Get-Date -Format 'yyyyMMdd_HHmmss'), $InstallationId
    )

    # A session-owned application lock must cover preflight AND deployment.
    $Connection = New-AIAFSqlConnection `
        -ServerInstance $ServerInstance `
        -DatabaseName $DatabaseName `
        -TrustServerCertificate:$TrustServerCertificate

    $ConnectionValidation = Test-AIAFSqlConnection `
        -Connection $Connection `
        -ExpectedDatabaseName $DatabaseName

    $AcquireResult = Enter-AIAFInstallationLock -Connection $Connection
    $LockAcquired = $true

    $Preflight = Test-AIAFPreflight `
        -Connection $Connection `
        -DatabaseName $DatabaseName `
        -Manifest $Manifest `
        -Parser $Parser

    $Preflight.Checks | Format-Table -AutoSize | Out-Host

    if (-not $Preflight.CanInstall) {
        throw "AIAF installation refused. $($Preflight.FailedChecks) preflight checks failed."
    }
    Write-Host 'Preflight validation passed.' -ForegroundColor Green

    # Preparse the entire selected plan before running the first deployment batch.
    # This rejects unsupported syntax without partially installing earlier scripts.
    foreach ($Item in $DeploymentPlan) {
        $ScriptContent = Get-Content -LiteralPath $Item.FullPath -Raw -Encoding UTF8
        $Parsed = Split-AIAFSqlBatches `
            -Sql $ScriptContent `
            -Parser $Parser `
            -SourceName $Item.Script

        if ($Parsed.BatchCount -le 0) {
            throw "Deployment script has no executable batches: $($Item.Script)"
        }

        $PreparedScripts.Add([PSCustomObject]@{
            Phase = $Item.Phase
            Script = $Item.Script
            Parsed = $Parsed
        })
    }

    if ($PlanOnly) {
        Write-Host ''
        Write-Host 'Deployment plan'
        Write-Host '---------------'
        $Sequence = 0
        foreach ($Item in $PreparedScripts) {
            $Sequence++
            [PSCustomObject]@{
                Sequence = $Sequence
                Phase = $Item.Phase
                Script = $Item.Script
                Batches = $Item.Parsed.BatchCount
            }
        }
        Write-Host ''
        Write-Host 'Plan-only execution completed.'
        Write-Host 'No deployment scripts were executed.'
        $InstallationStatus = 'PLAN_ONLY'
    }
    else {
        $ParsedSessionSettings = Split-AIAFSqlBatches `
            -Sql $SessionSettings `
            -Parser $Parser `
            -SourceName 'AIAF session settings'

        if ($ParsedSessionSettings.BatchCount -ne 1) {
            throw 'Unexpected session settings batch count.'
        }

        $Sequence = 0
        foreach ($Item in $PreparedScripts) {
            $Sequence++
            Write-Host ('[{0}/{1}] {2}' -f $Sequence, $PreparedScripts.Count, $Item.Script)
            $ScriptStartedAt = [DateTime]::UtcNow
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                # Both calls enforce exclusive lock ownership before and after each batch.
                [void](Invoke-AIAFSqlBatches `
                    -Connection $Connection `
                    -ParsedScript $ParsedSessionSettings `
                    -QueryTimeout $QueryTimeout)

                $Execution = Invoke-AIAFSqlBatches `
                    -Connection $Connection `
                    -ParsedScript $Item.Parsed `
                    -QueryTimeout $QueryTimeout

                foreach ($ResultSet in $Execution.ResultSets) {
                    $ResultSet.Table | Format-Table -AutoSize | Out-Host
                }

                $Stopwatch.Stop()
                $InstallationResults.Add([PSCustomObject]@{
                    Sequence = $Sequence
                    Phase = $Item.Phase
                    Script = $Item.Script
                    StartedAt = $ScriptStartedAt
                    CompletedAt = [DateTime]::UtcNow
                    DurationMs = $Stopwatch.ElapsedMilliseconds
                    BatchesExecuted = $Execution.BatchesExecuted
                    ResultSetCount = $Execution.ResultSetCount
                    Status = 'SUCCEEDED'
                    Error = $null
                })
                Write-Host ('  SUCCEEDED ({0} ms)' -f $Stopwatch.ElapsedMilliseconds) -ForegroundColor Green
            }
            catch {
                $Stopwatch.Stop()
                $InstallationResults.Add([PSCustomObject]@{
                    Sequence = $Sequence
                    Phase = $Item.Phase
                    Script = $Item.Script
                    StartedAt = $ScriptStartedAt
                    CompletedAt = [DateTime]::UtcNow
                    DurationMs = $Stopwatch.ElapsedMilliseconds
                    BatchesExecuted = $null
                    ResultSetCount = $null
                    Status = 'FAILED'
                    Error = $_.Exception.Message
                })
                throw
            }
        }
        $InstallationStatus = 'SUCCEEDED'
    }
}
catch {
    $InstallationStatus = 'FAILED'
    $InstallationError = $_.Exception.Message
    Write-Host ''
    Write-Host 'AIAF installation failed.' -ForegroundColor Red
    Write-Host 'No automatic cleanup was performed.'
    throw
}
finally {
    # Cleanup errors must not replace the original installation failure.
    if ($null -ne $Connection) {
        try {
            if ($LockAcquired -and
                $Connection.State -eq [System.Data.ConnectionState]::Open) {
                $LockReleaseResult = Exit-AIAFInstallationLock -Connection $Connection
            }
        }
        catch {
            $CleanupError = $_.Exception.Message
            Write-Warning "Installation lock release failed: $CleanupError"
        }
        finally {
            try { $Connection.Dispose() }
            catch {
                $DisposeError = $_.Exception.Message
                if ($null -eq $CleanupError) { $CleanupError = $DisposeError }
                Write-Warning "SQL connection disposal failed: $DisposeError"
            }
        }
    }

    $InstallationCompletedAt = [DateTime]::UtcNow
    $SucceededScripts = @($InstallationResults | Where-Object Status -eq 'SUCCEEDED').Count
    $FailedScripts = @($InstallationResults | Where-Object Status -eq 'FAILED').Count

    # A cleanup failure invalidates an otherwise successful installation report.
    if ($null -ne $CleanupError -and $InstallationStatus -ne 'FAILED') {
        $InstallationStatus = 'FAILED'
        $InstallationError = "SQL connection cleanup failed: $CleanupError"
    }

    $InstallationSummary = [PSCustomObject]@{
        InstallationId = $InstallationId
        ManifestVersion = $Manifest.ManifestVersion
        ServerInstance = $ServerInstance
        DatabaseName = $DatabaseName
        InstallationLogin = if ($null -ne $Preflight) { $Preflight.InstallationLogin } else { $null }
        Mode = $Mode
        PlanOnly = $PlanOnly.IsPresent
        StartedAt = $InstallationStartedAt
        CompletedAt = $InstallationCompletedAt
        DurationMs = [Math]::Round(($InstallationCompletedAt - $InstallationStartedAt).TotalMilliseconds)
        PreflightChecks = if ($null -ne $Preflight) { $Preflight.Checks } else { @() }
        PreflightCanInstall = if ($null -ne $Preflight) { $Preflight.CanInstall } else { $null }
        SessionId = if ($null -ne $ConnectionValidation) { $ConnectionValidation.SessionId } else { $null }
        ClientConnectionId = if ($null -ne $ConnectionValidation) { $ConnectionValidation.ClientConnectionId } else { $null }
        LockAcquired = $LockAcquired
        LockReleaseResult = $LockReleaseResult
        CleanupError = $CleanupError
        PlannedScripts = $DeploymentPlan.Count
        PreparedScripts = $PreparedScripts.Count
        SucceededScripts = $SucceededScripts
        FailedScripts = $FailedScripts
        NotExecutedScripts = $DeploymentPlan.Count - $SucceededScripts - $FailedScripts
        Status = $InstallationStatus
        Error = $InstallationError
        ScriptResults = $InstallationResults.ToArray()
    }

    if ($null -ne $LogFile) {
        try {
            $InstallationSummary | ConvertTo-Json -Depth 10 |
                Set-Content -LiteralPath $LogFile -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            $LogError = $_.Exception.Message
            Write-Warning "Could not write installation log: $LogError"
        }
    }

    Write-Host ''
    Write-Host '========================================'
    Write-Host ' Installation summary'
    Write-Host '========================================'
    $InstallationSummary |
        Select-Object InstallationId, DatabaseName, Mode, PlannedScripts,
            SucceededScripts, FailedScripts, NotExecutedScripts, DurationMs, Status |
        Format-List | Out-Host
    if ($null -ne $LogFile -and $null -eq $LogError) {
        Write-Host "Installation log: $LogFile"
    }
    if ($null -ne $CleanupError) {
        Write-Warning "Installation cleanup error: $CleanupError"
    }
}
