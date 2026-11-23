function New-AIAFSqlParser {

    [CmdletBinding()]
    param ()

    $ErrorActionPreference = 'Stop'

    $Module = Get-Module -Name SqlServer |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($null -eq $Module) {
        throw 'The SqlServer module must be loaded.'
    }

    $AssemblyDirectory = $Module.ModuleBase

    if ($PSVersionTable.PSEdition -eq 'Core') {
        $AssemblyDirectory = Join-Path `
            $AssemblyDirectory 'coreclr'
    }

    $AssemblyPath = Join-Path `
        $AssemblyDirectory `
        'Microsoft.SqlServer.TransactSql.ScriptDom.dll'

    if (-not (Test-Path `
        -LiteralPath $AssemblyPath `
        -PathType Leaf)) {

        throw "ScriptDom assembly not found: $AssemblyPath"
    }

    $ParserType = (
        'Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type]
    )

    if ($null -eq $ParserType) {

        Add-Type -Path $AssemblyPath -ErrorAction Stop

        $ParserType = (
            'Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type]
        )
    }

    if ($null -eq $ParserType) {
        throw 'The SQL Server 2022 ScriptDom parser is unavailable.'
    }

    return [System.Activator]::CreateInstance(
        $ParserType,
        [object[]]@($true)
    )
}

function Split-AIAFSqlBatches {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Sql,

        [Parameter(Mandatory = $true)]
        [object]$Parser,

        [ValidateNotNullOrEmpty()]
        [string]$SourceName = '<SQL text>'
    )

    $ErrorActionPreference = 'Stop'

    $Reader = [System.IO.StringReader]::new($Sql)
    $ParseErrors = $null

    try {

        $Fragment = $Parser.Parse(
            $Reader,
            [ref]$ParseErrors
        )
    }
    finally {

        $Reader.Dispose()
    }

    if ($null -eq $ParseErrors) {
        throw "Parser did not return an error collection: $SourceName"
    }

    if ($ParseErrors.Count -gt 0) {

        $ErrorDetails = (
            $ParseErrors | ForEach-Object {
                "Line $($_.Line), Column $($_.Column): $($_.Message)"
            }
        ) -join "`n"

        throw "SQL parsing failed: $SourceName`n$ErrorDetails"
    }

    if ($null -eq $Fragment -or
        $Fragment.GetType().Name -ne 'TSqlScript') {

        throw "Unexpected SQL parser result: $SourceName"
    }

    $GoTokens = @(
        $Fragment.ScriptTokenStream |
            Where-Object {
                $_.TokenType.ToString() -eq 'Go'
            }
    )

    $Segments = [System.Collections.Generic.List[object]]::new()

    $StartOffset = 0

    foreach ($Token in $GoTokens) {

        if ($Token.Offset -lt $StartOffset -or
            ($Token.Offset + $Token.Text.Length) -gt $Sql.Length) {

            throw "Invalid GO token boundary: $SourceName"
        }

        $Segments.Add(
            [PSCustomObject]@{
                StartOffset = $StartOffset
                EndOffset   = $Token.Offset
            }
        )

        $StartOffset = $Token.Offset + $Token.Text.Length
    }

    $Segments.Add(
        [PSCustomObject]@{
            StartOffset = $StartOffset
            EndOffset   = $Sql.Length
        }
    )

    $Batches = [System.Collections.Generic.List[object]]::new()

    foreach ($Segment in $Segments) {

        $MatchingBatches = @(
            $Fragment.Batches |
                Where-Object {
                    $_.StartOffset -ge $Segment.StartOffset -and
                    $_.StartOffset -lt $Segment.EndOffset
                }
        )

        # Ignore whitespace-only and comment-only segments.
        if ($MatchingBatches.Count -eq 0) {
            continue
        }

        if ($MatchingBatches.Count -ne 1) {
            throw "Unexpected batch boundaries: $SourceName"
        }

        $ParsedBatch = $MatchingBatches[0]

        if (($ParsedBatch.StartOffset +
            $ParsedBatch.FragmentLength) -gt $Segment.EndOffset) {

            throw "Parsed batch exceeds segment boundary: $SourceName"
        }

        $Length = $Segment.EndOffset - $Segment.StartOffset

        $BatchText = $Sql.Substring(
            $Segment.StartOffset,
            $Length
        )

        $Prefix = $Sql.Substring(
            0,
            $Segment.StartOffset
        )

        $StartLine = 1 + (
            [regex]::Matches(
                $Prefix,
                '\r\n|\n|\r'
            )
        ).Count

        $Batches.Add(
            [PSCustomObject]@{
                BatchNumber    = $Batches.Count + 1
                SourceName     = $SourceName
                StartOffset    = $Segment.StartOffset
                StartLine      = $StartLine
                StatementLine  = $ParsedBatch.StartLine
                StatementCount = $ParsedBatch.Statements.Count
                Sql            = $BatchText
            }
        )
    }

    if ($Batches.Count -ne $Fragment.Batches.Count) {

        throw (
            "Batch count mismatch in $SourceName. " +
            "Parsed: $($Fragment.Batches.Count). " +
            "Extracted: $($Batches.Count)."
        )
    }

    return [PSCustomObject]@{
        SourceName     = $SourceName
        BatchCount     = $Batches.Count
        StatementCount = (
            $Batches |
                Measure-Object StatementCount -Sum
        ).Sum
        GoTokenCount   = $GoTokens.Count
        Batches        = $Batches.ToArray()
    }
}

function Invoke-AIAFSqlBatches {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [Microsoft.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $true)]
        [object]$ParsedScript,

        [ValidateRange(1, 86400)]
        [int]$QueryTimeout = 300
    )

    $ErrorActionPreference = 'Stop'

    if ($Connection.State -ne
        [System.Data.ConnectionState]::Open) {

        throw 'An open SQL connection is required.'
    }

    if ($ParsedScript.BatchCount -le 0) {
        throw 'No executable SQL batches were supplied.'
    }

    $InitialConnectionId = $Connection.ClientConnectionId
    $InitialDatabase = $Connection.Database

	Assert-AIAFInstallationLock -Connection $Connection

    $ResultSets = [System.Collections.Generic.List[object]]::new()
    $BatchResults = [System.Collections.Generic.List[object]]::new()

    $ScriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($Batch in $ParsedScript.Batches) {

        if ($Connection.State -ne
            [System.Data.ConnectionState]::Open) {

            throw 'The installation connection is no longer open.'
        }

        if ($Connection.ClientConnectionId -ne
            $InitialConnectionId) {

            throw 'The installation connection identity has changed.'
        }

        if ($Connection.Database -cne $InitialDatabase) {
            throw 'The installation database context has changed.'
        }

		Assert-AIAFInstallationLock -Connection $Connection

        $Command = $null
        $Reader = $null

        $BatchStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $BatchResultSetCount = 0

        try {

            $Command = $Connection.CreateCommand()
            $Command.CommandTimeout = $QueryTimeout
            $Command.CommandText = $Batch.Sql

            $Reader = $Command.ExecuteReader()

            do {

                if ($Reader.FieldCount -gt 0) {

                    $Table = [System.Data.DataTable]::new()

                    for ($i = 0; $i -lt $Reader.FieldCount; $i++) {

                        $ColumnName = $Reader.GetName($i)

                        if ([string]::IsNullOrWhiteSpace(
                            $ColumnName)) {

                            $ColumnName = "Column$($i + 1)"
                        }

                        $BaseName = $ColumnName
                        $Suffix = 1

                        while ($Table.Columns.Contains($ColumnName)) {

                            $ColumnName = "${BaseName}_$Suffix"
                            $Suffix++
                        }

                        [void]$Table.Columns.Add(
                            $ColumnName,
                            $Reader.GetFieldType($i)
                        )
                    }

                    while ($Reader.Read()) {

                        $Values = [object[]]::new(
                            $Reader.FieldCount
                        )

                        [void]$Reader.GetValues($Values)

                        [void]$Table.Rows.Add($Values)
                    }

                    $BatchResultSetCount++

                    $ResultSets.Add(
                        [PSCustomObject]@{
                            BatchNumber = $Batch.BatchNumber
                            ResultSetNumber = $BatchResultSetCount
                            RowCount = $Table.Rows.Count
                            Table = $Table
                        }
                    )
                }

            } while ($Reader.NextResult())

            $Reader.Dispose()
            $Reader = $null

            if ($Connection.State -ne
                [System.Data.ConnectionState]::Open -or
                $Connection.ClientConnectionId -ne
                $InitialConnectionId -or
                $Connection.Database -cne $InitialDatabase) {

                throw 'Installation connection context changed during execution.'
            }

			Assert-AIAFInstallationLock -Connection $Connection

            $BatchStopwatch.Stop()

            $BatchResults.Add(
                [PSCustomObject]@{
                    BatchNumber = $Batch.BatchNumber
                    StartLine = $Batch.StartLine
                    StatementCount = $Batch.StatementCount
                    ResultSetCount = $BatchResultSetCount
                    DurationMs = $BatchStopwatch.ElapsedMilliseconds
                    Status = 'SUCCEEDED'
                }
            )
        }
        catch {

            $BatchStopwatch.Stop()

            $Message = (
                "SQL batch execution failed. " +
                "Source: $($ParsedScript.SourceName). " +
                "Batch: $($Batch.BatchNumber). " +
                "Starting line: $($Batch.StartLine). " +
                "Error: $($_.Exception.Message)"
            )

            throw [System.InvalidOperationException]::new(
                $Message,
                $_.Exception
            )
        }
        finally {

            if ($null -ne $Reader) {
                $Reader.Dispose()
            }

            if ($null -ne $Command) {
                $Command.Dispose()
            }
        }
    }

    $ScriptStopwatch.Stop()

    return [PSCustomObject]@{
        SourceName = $ParsedScript.SourceName
        DatabaseName = $InitialDatabase
        ClientConnectionId = $InitialConnectionId
        BatchesExecuted = $BatchResults.Count
        ResultSetCount = $ResultSets.Count
        DurationMs = $ScriptStopwatch.ElapsedMilliseconds
        BatchResults = $BatchResults.ToArray()
        ResultSets = $ResultSets.ToArray()
        Status = 'SUCCEEDED'
    }
}