[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ServerInstance,

    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# Normalize the output path using PowerShell's working directory.
$OutputPath = $ExecutionContext.SessionState.Path.
    GetUnresolvedProviderPathFromPSPath($OutputPath)

Import-Module SqlServer -ErrorAction Stop

# Define the schemas included in the reference deployment.

$schemas = @(
    'acme'
    'aiaf'
    'aiaf_governance'
    'aiaf_tool'
)

# Connect to the source database.

$server = New-Object Microsoft.SqlServer.Management.Smo.Server `
    -ArgumentList $ServerInstance

$db = $server.Databases[$DatabaseName]

if ($null -eq $db) {
    throw "Database '$DatabaseName' was not found."
}

if ([int]$db.CompatibilityLevel -lt 160) {
    throw "AIAF requires database compatibility level 160 or higher."
}

Write-Host "=============================================="
Write-Host "AIAF DATABASE EXTRACTION"
Write-Host "=============================================="
Write-Host "Server:        $ServerInstance"
Write-Host "Database:      $DatabaseName"
Write-Host "Compatibility: $($db.CompatibilityLevel)"
Write-Host "Collation:     $($db.Collation)"
Write-Host "Output:        $OutputPath"
Write-Host ""

# Create output directories.

$setupPath = Join-Path $OutputPath '00_setup'
$schemaPath = Join-Path $OutputPath '01_schema'
$constraintPath = Join-Path $OutputPath '03_constraints'
$indexPath = Join-Path $OutputPath '04_indexes'
$viewPath = Join-Path $OutputPath '05_views'
$procedurePath = Join-Path $OutputPath '06_procedures'

New-Item -ItemType Directory -Force `
    -Path $setupPath, `
          $schemaPath, `
          $constraintPath, `
          $indexPath, `
          $viewPath, `
          $procedurePath | Out-Null

# Configure SMO scripting options.

$options = New-Object `
    Microsoft.SqlServer.Management.Smo.ScriptingOptions

$options.ScriptSchema = $true
$options.ScriptData = $false
$options.ScriptDrops = $false

$options.SchemaQualify = $true
$options.SchemaQualifyForeignKeysReferences = $true
$options.IncludeHeaders = $false
$options.IncludeDatabaseContext = $false

$options.DriAll = $false
$options.DriPrimaryKey = $true
$options.DriUniqueKeys = $true
$options.DriChecks = $true
$options.DriDefaults = $true
$options.DriForeignKeys = $false

$options.Indexes = $false
$options.Triggers = $false
$options.ExtendedProperties = $false

$options.Permissions = $false
$options.ScriptOwner = $true
$options.WithDependencies = $false

$options.TargetServerVersion = `
    [Microsoft.SqlServer.Management.Smo.SqlServerVersion]::Version160

# Write generated SQL batches with explicit separators.

function Write-SqlScript {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Batches
    )

    $separator = "`r`nGO`r`n`r`n"

    $content = ($Batches -join $separator) +
        "`r`nGO`r`n"

    $encoding = [System.Text.UTF8Encoding]::new($false)

    [System.IO.File]::WriteAllText(
        $Path,
        $content,
        $encoding
    )
}

# Export application schemas.

Write-Host "Extracting schemas..."

$schemaCount = 0

foreach ($schemaName in $schemas) {

    $schema = $db.Schemas[$schemaName]

    if ($null -eq $schema) {
        throw "Required schema '$schemaName' was not found."
    }

    $fileName = "Schema_$schemaName.sql"
    $filePath = Join-Path $setupPath $fileName

    Write-SqlScript `
        -Path $filePath `
        -Batches @($schema.Script($options))

    $schemaCount++

    Write-Host "  Exported schema: $schemaName"
}

# Export tables without cross-table foreign keys
# or additional nonconstraint indexes.

Write-Host ""
Write-Host "Extracting tables..."

$tables = @(
    $db.Tables |
        Where-Object {
            $_.Schema -in $schemas -and
            -not $_.IsSystemObject
        } |
        Sort-Object Schema, Name
)

$tableCount = 0

foreach ($table in $tables) {

    $qualifiedName = "$($table.Schema).$($table.Name)"
    $fileName = "$qualifiedName.sql"
    $filePath = Join-Path $schemaPath $fileName

    Write-SqlScript `
        -Path $filePath `
        -Batches @($table.Script($options))

    $tableCount++

    Write-Host "  Exported table: $qualifiedName"
}

# Export cross-table foreign key constraints.

Write-Host ""
Write-Host "Extracting foreign keys..."

$foreignKeyCount = 0

foreach ($table in $tables) {

    foreach ($foreignKey in $table.ForeignKeys) {

        $qualifiedName = "$($table.Schema).$($table.Name)"

        $fileName = "$qualifiedName.$($foreignKey.Name).sql"
        $filePath = Join-Path $constraintPath $fileName

        Write-SqlScript `
            -Path $filePath `
            -Batches @($foreignKey.Script($options))

        $foreignKeyCount++

        Write-Host "  Exported foreign key: $($foreignKey.Name)"
    }
}

# Export additional indexes. Primary keys and unique constraints were already exported with the table definitions.

Write-Host ""
Write-Host "Extracting nonconstraint indexes..."

$indexCount = 0
$filteredIndexCount = 0
$uniqueIndexCount = 0

foreach ($table in $tables) {

    $indexes = @(
        $table.Indexes |
            Where-Object {
                $_.IndexKeyType -eq 'None' -and
                -not $_.IsHypothetical
            } |
            Sort-Object Name
    )

    foreach ($index in $indexes) {

        $qualifiedName = "$($table.Schema).$($table.Name)"

        $fileName = "$qualifiedName.$($index.Name).sql"
        $filePath = Join-Path $indexPath $fileName

        Write-SqlScript `
            -Path $filePath `
            -Batches @($index.Script($options))

        $indexCount++

        if ($index.HasFilter) {
            $filteredIndexCount++
        }

        if ($index.IsUnique) {
            $uniqueIndexCount++
        }

        Write-Host "  Exported index: $($index.Name)"
    }
}

# Export application views.
# Ledger-generated views are created automatically.

Write-Host ""
Write-Host "Extracting views..."

$viewCount = 0

$views = @(
    $db.Views |
        Where-Object {
            $_.Schema -in $schemas -and
            -not $_.IsSystemObject -and
            -not (
                $_.Schema -eq 'aiaf' -and
                $_.Name -eq 'AIInteractionEvent_Ledger'
            )
        } |
        Sort-Object Schema, Name
)

foreach ($view in $views) {

    $qualifiedName = "$($view.Schema).$($view.Name)"

    $fileName = "$qualifiedName.sql"
    $filePath = Join-Path $viewPath $fileName

    Write-SqlScript `
        -Path $filePath `
        -Batches @($view.Script($options))

    $viewCount++

    Write-Host "  Exported view: $qualifiedName"
}

# Export application stored procedures.

Write-Host ""
Write-Host "Extracting stored procedures..."

$procedureCount = 0

$procedures = @(
    $db.StoredProcedures |
        Where-Object {
            $_.Schema -in $schemas -and
            -not $_.IsSystemObject
        } |
        Sort-Object Schema, Name
)

foreach ($procedure in $procedures) {

    $qualifiedName = "$($procedure.Schema).$($procedure.Name)"

    $fileName = "$qualifiedName.sql"
    $filePath = Join-Path $procedurePath $fileName

    Write-SqlScript `
        -Path $filePath `
        -Batches @($procedure.Script($options))

    $procedureCount++

    Write-Host "  Exported procedure: $qualifiedName"
}

# Display extraction summary.

Write-Host ""
Write-Host "=============================================="
Write-Host "EXTRACTION SUMMARY"
Write-Host "=============================================="
Write-Host "Schemas exported:       $schemaCount"
Write-Host "Tables exported:        $tableCount"
Write-Host "Foreign keys exported:  $foreignKeyCount"
Write-Host "Indexes exported:       $indexCount"
Write-Host "  Filtered indexes:     $filteredIndexCount"
Write-Host "  Unique indexes:       $uniqueIndexCount"
Write-Host "Views exported:         $viewCount"
Write-Host "Procedures exported:    $procedureCount"
Write-Host "Data exported:          No"
Write-Host "Output directory:       $OutputPath"
Write-Host "=============================================="