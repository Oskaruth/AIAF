function Test-AIAFPreflight {

    [CmdletBinding()]
	param (

		[Parameter(Mandatory = $true)]
		[Microsoft.Data.SqlClient.SqlConnection]$Connection,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$DatabaseName,

		[Parameter(Mandatory = $true)]
		[hashtable]$Manifest,

		[Parameter(Mandatory = $true)]
		[object]$Parser
	)

    $ErrorActionPreference = 'Stop'

    $QueryPath = Join-Path $PSScriptRoot 'AIAF.Preflight.sql'

    if (-not (Test-Path -LiteralPath $QueryPath -PathType Leaf)) {
        throw "Preflight SQL script not found: $QueryPath"
    }

	$ConnectionValidation = Test-AIAFSqlConnection `
		-Connection $Connection `
		-ExpectedDatabaseName $DatabaseName

	Assert-AIAFInstallationLock `
		-Connection $Connection

	$Sql = Get-Content `
		-LiteralPath $QueryPath `
		-Raw `
		-Encoding UTF8

	$Parsed = Split-AIAFSqlBatches `
		-Sql $Sql `
		-Parser $Parser `
		-SourceName 'AIAF.Preflight.sql'

	$Execution = Invoke-AIAFSqlBatches `
		-Connection $Connection `
		-ParsedScript $Parsed `
		-QueryTimeout 60

	if ($Execution.Status -cne 'SUCCEEDED') {
		throw 'Preflight SQL execution did not succeed.'
	}

	$Results = @(
		foreach ($ResultSet in $Execution.ResultSets) {

			# Prevent PowerShell from enumerating DataTable rows.
			,($ResultSet.Table)
		}
	)

    if ($Results.Count -ne 4) {
        throw "Expected four preflight result sets. Received $($Results.Count)."
    }

    if ($Results[0].Rows.Count -ne 1) {
        throw 'Expected exactly one database configuration row.'
    }

    $Configuration = $Results[0].Rows[0]

    $ExistingSchemas = $Results[1]
    $ExistingObjects = $Results[2]
    $ExistingPrincipals = $Results[3]

    $Checks = [System.Collections.Generic.List[object]]::new()

    function Add-PreflightCheck {

        param (
            [string]$CheckName,
            [object]$Expected,
            [object]$Actual,
            [bool]$Passed
        )

        $Checks.Add(
            [PSCustomObject]@{
                CheckName = $CheckName
                Expected  = $Expected
                Actual    = $Actual
                Result    = if ($Passed) { 'PASS' } else { 'FAIL' }
            }
        )
    }

    # =================================================
    # Database target
    # =================================================

    Add-PreflightCheck `
        -CheckName 'Target database' `
        -Expected $DatabaseName `
        -Actual $Configuration.DatabaseName `
        -Passed ($Configuration.DatabaseName -eq $DatabaseName)

    Add-PreflightCheck `
        -CheckName 'Non-system database' `
        -Expected 'DatabaseId > 4' `
        -Actual $Configuration.DatabaseId `
        -Passed ($Configuration.DatabaseId -gt 4)

    # =================================================
    # SQL Server platform
    # =================================================

    Add-PreflightCheck `
        -CheckName 'SQL Server engine edition' `
        -Expected '2, 3 or 4' `
        -Actual $Configuration.EngineEdition `
        -Passed ($Configuration.EngineEdition -in @(2, 3, 4))

    Add-PreflightCheck `
        -CheckName 'SQL Server major version' `
        -Expected ">= $($Manifest.MinimumSqlServerMajorVersion)" `
        -Actual $Configuration.ProductMajorVersion `
        -Passed (
            $Configuration.ProductMajorVersion -ge
            $Manifest.MinimumSqlServerMajorVersion
        )

    # =================================================
    # Database configuration
    # =================================================

    Add-PreflightCheck `
        -CheckName 'Compatibility level' `
        -Expected ">= $($Manifest.MinimumCompatibilityLevel)" `
        -Actual $Configuration.CompatibilityLevel `
        -Passed (
            $Configuration.CompatibilityLevel -ge
            $Manifest.MinimumCompatibilityLevel
        )

    Add-PreflightCheck `
        -CheckName 'Database collation' `
        -Expected $Manifest.RequiredCollation `
        -Actual $Configuration.CollationName `
        -Passed (
            $Configuration.CollationName -eq
            $Manifest.RequiredCollation
        )

    Add-PreflightCheck `
        -CheckName 'Database state' `
        -Expected 'ONLINE' `
        -Actual $Configuration.DatabaseState `
        -Passed ($Configuration.DatabaseState -eq 'ONLINE')

    Add-PreflightCheck `
        -CheckName 'Database access' `
        -Expected 'MULTI_USER' `
        -Actual $Configuration.UserAccess `
        -Passed ($Configuration.UserAccess -eq 'MULTI_USER')

    Add-PreflightCheck `
        -CheckName 'Read-only database' `
        -Expected $false `
        -Actual $Configuration.IsReadOnly `
        -Passed ($Configuration.IsReadOnly -eq $false)

    Add-PreflightCheck `
        -CheckName 'Snapshot isolation' `
        -Expected 'ON' `
        -Actual $Configuration.SnapshotIsolationState `
        -Passed (
            $Configuration.SnapshotIsolationState -eq 'ON'
        )

    Add-PreflightCheck `
        -CheckName 'Read committed snapshot' `
        -Expected $false `
        -Actual $Configuration.IsReadCommittedSnapshotOn `
        -Passed (
            $Configuration.IsReadCommittedSnapshotOn -eq $false
        )

    Add-PreflightCheck `
        -CheckName 'Trustworthy database' `
        -Expected $false `
        -Actual $Configuration.IsTrustworthyOn `
        -Passed ($Configuration.IsTrustworthyOn -eq $false)

    Add-PreflightCheck `
        -CheckName 'Database chaining' `
        -Expected $false `
        -Actual $Configuration.IsDatabaseChainingOn `
        -Passed ($Configuration.IsDatabaseChainingOn -eq $false)

	# Server-level ownership chaining
	$ServerCrossDbChainingConfigured =
		$Configuration.ServerCrossDbChainingConfigured

	$ServerCrossDbChainingRunning =
		$Configuration.ServerCrossDbChainingRunning

	Add-PreflightCheck `
		-CheckName 'Server cross-database chaining (configured)' `
		-Expected 0 `
		-Actual $ServerCrossDbChainingConfigured `
		-Passed (
			$null -ne $ServerCrossDbChainingConfigured -and
			$ServerCrossDbChainingConfigured -isnot [System.DBNull] -and
			$ServerCrossDbChainingConfigured -is [int] -and
			$ServerCrossDbChainingConfigured -eq 0
		)

	Add-PreflightCheck `
		-CheckName 'Server cross-database chaining (running)' `
		-Expected 0 `
		-Actual $ServerCrossDbChainingRunning `
		-Passed (
			$null -ne $ServerCrossDbChainingRunning -and
			$ServerCrossDbChainingRunning -isnot [System.DBNull] -and
			$ServerCrossDbChainingRunning -is [int] -and
			$ServerCrossDbChainingRunning -eq 0
		)

    Add-PreflightCheck `
        -CheckName 'Database-level ledger' `
        -Expected $false `
        -Actual $Configuration.IsLedgerDatabase `
        -Passed ($Configuration.IsLedgerDatabase -eq $false)

    # =================================================
    # Installation permissions
    # =================================================

    $HasInstallationPermissions = (
        $Configuration.IsDbOwner -eq 1 -or
        $Configuration.IsSysAdmin -eq 1
    )

    Add-PreflightCheck `
        -CheckName 'Installation permissions' `
        -Expected 'db_owner or sysadmin' `
        -Actual $HasInstallationPermissions `
        -Passed $HasInstallationPermissions

    # =================================================
    # Existing framework detection
    # =================================================

    Add-PreflightCheck `
        -CheckName 'Existing AIAF schemas' `
        -Expected 0 `
        -Actual $ExistingSchemas.Rows.Count `
        -Passed ($ExistingSchemas.Rows.Count -eq 0)

    Add-PreflightCheck `
        -CheckName 'Existing AIAF objects' `
        -Expected 0 `
        -Actual $ExistingObjects.Rows.Count `
        -Passed ($ExistingObjects.Rows.Count -eq 0)

    Add-PreflightCheck `
        -CheckName 'Existing AIAF principals' `
        -Expected 0 `
        -Actual $ExistingPrincipals.Rows.Count `
        -Passed ($ExistingPrincipals.Rows.Count -eq 0)

    # =================================================
    # Return structured preflight results
    # =================================================

    $FailedChecks = @(
        $Checks | Where-Object Result -eq 'FAIL'
    )

	$PostValidation = Test-AIAFSqlConnection `
		-Connection $Connection `
		-ExpectedDatabaseName $DatabaseName

	if ($PostValidation.SessionId -ne
			$ConnectionValidation.SessionId -or
		$PostValidation.ClientConnectionId -ne
			$ConnectionValidation.ClientConnectionId) {

		throw 'SQL connection identity changed during preflight.'
	}

	Assert-AIAFInstallationLock `
		-Connection $Connection

    [PSCustomObject]@{
        ServerInstance 		= $Connection.DataSource
		ServerName 			= $Configuration.ServerName
		SessionId 			= $ConnectionValidation.SessionId
		ClientConnectionId 	= $ConnectionValidation.ClientConnectionId
		InstallationLockVerified = $true
		ExecutionDurationMs = $Execution.DurationMs
        DatabaseName       = $DatabaseName
        EvaluatedAtUtc     = [DateTime]::UtcNow
        InstallationLogin  = $Configuration.InstallationLogin
        TotalChecks        = $Checks.Count
        PassedChecks       = $Checks.Count - $FailedChecks.Count
        FailedChecks       = $FailedChecks.Count
        CanInstall         = ($FailedChecks.Count -eq 0)
        Checks             = $Checks.ToArray()
        Configuration      = $Configuration
        ExistingSchemas    = $ExistingSchemas
        ExistingObjects    = $ExistingObjects
        ExistingPrincipals = $ExistingPrincipals
    }
}