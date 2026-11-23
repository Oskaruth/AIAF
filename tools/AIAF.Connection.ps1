function New-AIAFSqlConnection {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerInstance,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName,

        [switch]$TrustServerCertificate
    )

    $ErrorActionPreference = 'Stop'

    $Builder = New-Object `
        Microsoft.Data.SqlClient.SqlConnectionStringBuilder

    $Builder['Data Source'] = $ServerInstance
    $Builder['Initial Catalog'] = $DatabaseName
    $Builder['Integrated Security'] = $true
    $Builder['Encrypt'] = 'Mandatory'
    $Builder['Trust Server Certificate'] =
        $TrustServerCertificate.IsPresent

    $Builder['Connect Timeout'] = 30
    $Builder['Connect Retry Count'] = 0
    $Builder['Pooling'] = $false
    $Builder['MultipleActiveResultSets'] = $false
    $Builder['Application Name'] = 'AIAF Database Installer'

    $Connection = New-Object `
        Microsoft.Data.SqlClient.SqlConnection

    try {

        $Connection.ConnectionString =
            $Builder.ConnectionString

        $Connection.Open()

        return $Connection
    }
    catch {

        $Connection.Dispose()

        throw
    }
}

function Enter-AIAFInstallationLock {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Data.SqlClient.SqlConnection]$Connection
    )

    $ErrorActionPreference = 'Stop'

    if ($Connection.State -ne [System.Data.ConnectionState]::Open) {
        throw 'An open SQL connection is required.'
    }

    $Command = $Connection.CreateCommand()

    try {

        $Command.CommandTimeout = 30

        $Command.CommandText = @'
DECLARE @Result int;

EXEC @Result = sys.sp_getapplock
    @Resource = N'AIAF.DatabaseInstallation',
    @LockMode = 'Exclusive',
    @LockOwner = 'Session',
    @LockTimeout = 0,
    @DbPrincipal = 'public';

SELECT @Result;
'@

        $Result = $Command.ExecuteScalar()

        if ($null -eq $Result -or
            $Result -isnot [int]) {

            throw 'Unexpected application lock result.'
        }

        switch ($Result) {

            0 { break }

            1 { break }

            -1 {
                throw 'Another AIAF installation holds the installation lock.'
            }

            -2 {
                throw 'The installation lock request was canceled.'
            }

            -3 {
                throw 'The installation lock request was a deadlock victim.'
            }

            default {
                throw "Installation lock acquisition failed. Return code: $Result"
            }
        }

        return $Result
    }
    finally {

        $Command.Dispose()
    }
}

function Exit-AIAFInstallationLock {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Data.SqlClient.SqlConnection]$Connection
    )

    $ErrorActionPreference = 'Stop'

    if ($Connection.State -ne [System.Data.ConnectionState]::Open) {
        throw 'An open SQL connection is required.'
    }

    $Command = $Connection.CreateCommand()

    try {

        $Command.CommandTimeout = 30

        $Command.CommandText = @'
DECLARE @Result int;

EXEC @Result = sys.sp_releaseapplock
    @Resource = N'AIAF.DatabaseInstallation',
    @LockOwner = 'Session',
    @DbPrincipal = 'public';

SELECT @Result;
'@

        $Result = $Command.ExecuteScalar()

        if ($null -eq $Result -or
            $Result -isnot [int] -or
            $Result -ne 0) {

            throw "Installation lock release failed. Return code: $Result"
        }

        return $Result
    }
    finally {

        $Command.Dispose()
    }
}

function Test-AIAFSqlConnection {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedDatabaseName
    )

    $ErrorActionPreference = 'Stop'

    if ($Connection.State -ne [System.Data.ConnectionState]::Open) {
        throw 'An open SQL connection is required.'
    }

    $Command = $Connection.CreateCommand()
    $Reader = $null

    try {

        $Command.CommandTimeout = 30

        $Command.CommandText = @'
SET NOCOUNT ON;

SELECT
    CONVERT(sysname, SERVERPROPERTY('ServerName'))
        AS ServerName,
    DB_NAME() AS DatabaseName,
    CONVERT(int, DB_ID()) AS DatabaseId,
    CONVERT(int, @@SPID) AS SessionId,
    ORIGINAL_LOGIN() AS OriginalLogin,
    SUSER_SNAME() AS EffectiveLogin,
    USER_NAME() AS DatabaseUser,
    C.net_transport AS NetworkTransport,
    C.protocol_type AS ProtocolType,
    C.encrypt_option AS EncryptionEnabled,
    C.auth_scheme AS AuthenticationScheme,
    CONVERT(int, C.endpoint_id) AS EndpointId,
    E.name AS EndpointName,
    CONVERT(bit,
        CASE
            WHEN E.endpoint_id IS NULL THEN NULL
            WHEN E.name = N'Dedicated Admin Connection' THEN 1
            ELSE 0
        END
    ) AS IsDedicatedAdminConnection,
    C.local_tcp_port AS LocalTcpPort
FROM sys.dm_exec_connections AS C
LEFT JOIN sys.endpoints AS E
    ON C.endpoint_id = E.endpoint_id
WHERE C.session_id = @@SPID;
'@

        $Reader = $Command.ExecuteReader()

        $Results = [System.Data.DataTable]::new()
        $Results.Load($Reader)

        if ($Results.Rows.Count -ne 1) {
            throw 'Expected exactly one SQL connection metadata row.'
        }

        $Configuration = $Results.Rows[0]

        if ($Configuration.DatabaseName -cne $ExpectedDatabaseName) {
            throw 'Connected database does not match the requested database.'
        }

        if ($Configuration.DatabaseId -isnot [int] -or
            $Configuration.DatabaseId -le 4) {
            throw 'Installation into a system or unidentified database is prohibited.'
        }

        if ($Configuration.EncryptionEnabled -cne 'TRUE') {
            throw 'SQL connection encryption could not be verified.'
        }

        if ($Configuration.ProtocolType -cne 'TSQL') {
            throw 'Unexpected SQL connection protocol.'
        }

        if ($Configuration.IsDedicatedAdminConnection -isnot [bool] -or
            [string]::IsNullOrWhiteSpace(
                [string]$Configuration.EndpointName
            )) {

            throw 'SQL connection endpoint could not be verified.'
        }

        if ($Configuration.IsDedicatedAdminConnection) {
            throw 'AIAF installation through a Dedicated Administrator Connection is prohibited.'
        }

        if ($Configuration.AuthenticationScheme -notin @(
            'NTLM',
            'KERBEROS'
        )) {

            throw 'SQL connection is not using supported Windows authentication.'
        }

        if ([string]::IsNullOrWhiteSpace(
                [string]$Configuration.OriginalLogin
            ) -or
            [string]::IsNullOrWhiteSpace(
                [string]$Configuration.EffectiveLogin
            ) -or
            $Configuration.OriginalLogin -cne
                $Configuration.EffectiveLogin) {

            throw 'SQL connection login identity could not be verified.'
        }

        return [PSCustomObject]@{
            ServerName                 = $Configuration.ServerName
            DatabaseName               = $Configuration.DatabaseName
            DatabaseId                 = $Configuration.DatabaseId
            SessionId                  = $Configuration.SessionId
            ClientConnectionId         = $Connection.ClientConnectionId
            OriginalLogin              = $Configuration.OriginalLogin
            EffectiveLogin             = $Configuration.EffectiveLogin
            DatabaseUser               = $Configuration.DatabaseUser
            NetworkTransport           = $Configuration.NetworkTransport
            ProtocolType               = $Configuration.ProtocolType
            EncryptionEnabled          = $Configuration.EncryptionEnabled
            AuthenticationScheme       = $Configuration.AuthenticationScheme
            EndpointId                 = $Configuration.EndpointId
            EndpointName               = $Configuration.EndpointName
            IsDedicatedAdminConnection = $Configuration.IsDedicatedAdminConnection
            LocalTcpPort               = $Configuration.LocalTcpPort
            Validated                  = $true
        }
    }
    finally {

        if ($null -ne $Reader) {
            $Reader.Dispose()
        }

        $Command.Dispose()
    }
}

function Assert-AIAFInstallationLock {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [Microsoft.Data.SqlClient.SqlConnection]$Connection
    )

    $ErrorActionPreference = 'Stop'

    if ($Connection.State -ne
        [System.Data.ConnectionState]::Open) {

        throw 'An open SQL connection is required.'
    }

    $Command = $Connection.CreateCommand()

    try {

        $Command.CommandTimeout = 30

        $Command.CommandText = @'
SET NOCOUNT ON;

SELECT APPLOCK_MODE(
    N'public',
    N'AIAF.DatabaseInstallation',
    N'Session'
);
'@

        $LockMode = $Command.ExecuteScalar()

        if ($LockMode -isnot [string] -or
            $LockMode -cne 'Exclusive') {

            throw 'The current SQL session does not hold the exclusive AIAF installation lock.'
        }
    }
    finally {

        $Command.Dispose()
    }
}