#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only preflight for a fresh AIAF SQL Server deployment.
.EXAMPLE
    .\tools\Test-AIAFDatabase.ps1 -ServerInstance 'btg-kwilkie' -Database 'AIAF_DeploymentTest' -TrustServerCertificate
.NOTES
    Does not create or alter database objects. Requires sqlcmd on PATH.
    Exit 0 = pass; exit 1 = failed checks; exit 2 = connection/query error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerInstance,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Database,

    [switch]$TrustServerCertificate
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    Write-Error 'sqlcmd.exe was not found on PATH.'
    exit 2
}

# Escape the target name as a SQL Unicode string literal. QUOTENAME is used
# inside SQL for cross-database metadata access.
$escapedDatabase = $Database.Replace("'", "''")
if ($Database -match '[\r\n]') {
    Write-Error 'Database name cannot contain line breaks.'
    exit 2
}

$query = @'
SET NOCOUNT ON;
DECLARE @Target sysname = N'__TARGET_DATABASE__';
DECLARE @Major int = TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));
DECLARE @DbId int = DB_ID(@Target);
DECLARE @State nvarchar(60), @Access nvarchar(60), @Collation sysname;
DECLARE @ReadOnly bit, @Compat int, @Snapshot nvarchar(60), @Rcsi bit;
DECLARE @Recovery nvarchar(60), @AgId uniqueidentifier, @Primary int;
DECLARE @Check TABLE (CheckName nvarchar(100), Result varchar(5), Detail nvarchar(4000));

INSERT @Check VALUES ('SQL Server version', CASE WHEN @Major >= 16 THEN 'PASS' ELSE 'FAIL' END,
    CONCAT('Major version: ', COALESCE(CONVERT(varchar(20),@Major),'unknown'), '; minimum 16'));
INSERT @Check VALUES ('Database exists', CASE WHEN @DbId IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    CONCAT('Target: ', @Target));

IF @DbId IS NOT NULL
BEGIN
    SELECT @State=state_desc, @Access=user_access_desc, @ReadOnly=is_read_only,
        @Compat=compatibility_level, @Collation=collation_name,
        @Snapshot=snapshot_isolation_state_desc, @Rcsi=is_read_committed_snapshot_on,
        @Recovery=recovery_model_desc, @AgId=group_database_id
    FROM sys.databases WHERE database_id=@DbId;

    INSERT @Check VALUES ('Database ONLINE', CASE WHEN @State='ONLINE' THEN 'PASS' ELSE 'FAIL' END, COALESCE(@State,'unknown'));
    INSERT @Check VALUES ('Database MULTI_USER', CASE WHEN @Access='MULTI_USER' THEN 'PASS' ELSE 'FAIL' END, COALESCE(@Access,'unknown'));
    INSERT @Check VALUES ('Database writable', CASE WHEN @ReadOnly=0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('is_read_only=',@ReadOnly));
    INSERT @Check VALUES ('Compatibility level', CASE WHEN @Compat>=160 THEN 'PASS' ELSE 'FAIL' END, CONCAT('Level=',@Compat,'; minimum 160'));
    INSERT @Check VALUES ('Lab collation', CASE WHEN @Collation='Latin1_General_100_CI_AS_SC_UTF8' THEN 'PASS' ELSE 'FAIL' END, COALESCE(@Collation,'unknown'));
    INSERT @Check VALUES ('Snapshot isolation', CASE WHEN @Snapshot='ON' THEN 'PASS' ELSE 'FAIL' END, COALESCE(@Snapshot,'unknown'));
    INSERT @Check VALUES ('Recovery model (info)', 'INFO', COALESCE(@Recovery,'unknown'));
    INSERT @Check VALUES ('RCSI (info)', 'INFO', CONCAT('is_read_committed_snapshot_on=',@Rcsi));

    IF @AgId IS NULL
        INSERT @Check VALUES ('AG deployment target', 'PASS', 'Standalone database (not in AG)');
    ELSE
    BEGIN
        SELECT @Primary=sys.fn_hadr_is_primary_replica(@Target);
        INSERT @Check VALUES ('AG deployment target', CASE WHEN @Primary=1 THEN 'PASS' ELSE 'FAIL' END,
            CASE WHEN @Primary=1 THEN 'Primary replica' WHEN @Primary=0 THEN 'Secondary replica' ELSE 'Primary status unavailable' END);
    END;

    IF @State='ONLINE'
    BEGIN
        DECLARE @SchemaCount int=0, @ObjectCount int=0, @PrincipalCount int=0;
        DECLARE @HasCreateDb bit=0, @HasAlterAnySchema bit=0, @HasAlterAnyRole bit=0;
        DECLARE @sql nvarchar(max)=N'
            SELECT @Schemas=COUNT(*) FROM ' + QUOTENAME(@Target) + N'.sys.schemas
            WHERE name IN (N''aiaf'',N''aiaf_governance'',N''aiaf_tool'',N''acme'');
            SELECT @Objects=COUNT(*) FROM ' + QUOTENAME(@Target) + N'.sys.objects
            WHERE schema_id IN (SELECT schema_id FROM ' + QUOTENAME(@Target) + N'.sys.schemas
                WHERE name IN (N''aiaf'',N''aiaf_governance'',N''aiaf_tool'',N''acme''));
            SELECT @Principals=COUNT(*) FROM ' + QUOTENAME(@Target) + N'.sys.database_principals
            WHERE name LIKE N''AIAF[_]%'';
            USE ' + QUOTENAME(@Target) + N';
            SELECT @CreateDb=CONVERT(bit,HAS_PERMS_BY_NAME(DB_NAME(),N''DATABASE'',N''CREATE TABLE'')),
                @AlterSchema=CONVERT(bit,HAS_PERMS_BY_NAME(DB_NAME(),N''DATABASE'',N''ALTER ANY SCHEMA'')),
                @AlterRole=CONVERT(bit,HAS_PERMS_BY_NAME(DB_NAME(),N''DATABASE'',N''ALTER ANY ROLE''));';
        BEGIN TRY
            EXEC sys.sp_executesql @sql,
                N'@Schemas int OUTPUT,@Objects int OUTPUT,@Principals int OUTPUT,@CreateDb bit OUTPUT,@AlterSchema bit OUTPUT,@AlterRole bit OUTPUT',
                @Schemas=@SchemaCount OUTPUT,@Objects=@ObjectCount OUTPUT,@Principals=@PrincipalCount OUTPUT,
                @CreateDb=@HasCreateDb OUTPUT,@AlterSchema=@HasAlterAnySchema OUTPUT,@AlterRole=@HasAlterAnyRole OUTPUT;
            INSERT @Check VALUES ('Fresh install: schemas', CASE WHEN @SchemaCount=0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('AIAF-related schemas=',@SchemaCount));
            INSERT @Check VALUES ('Fresh install: objects', CASE WHEN @ObjectCount=0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('AIAF-related objects=',@ObjectCount));
            INSERT @Check VALUES ('Fresh install: principals', CASE WHEN @PrincipalCount=0 THEN 'PASS' ELSE 'FAIL' END, CONCAT('AIAF-prefixed principals=',@PrincipalCount));
            INSERT @Check VALUES ('CREATE TABLE permission', CASE WHEN @HasCreateDb=1 THEN 'PASS' ELSE 'FAIL' END, CONCAT('Effective permission=',COALESCE(CONVERT(varchar(5),@HasCreateDb),'NULL')));
            INSERT @Check VALUES ('ALTER ANY SCHEMA permission', CASE WHEN @HasAlterAnySchema=1 THEN 'PASS' ELSE 'FAIL' END, CONCAT('Effective permission=',COALESCE(CONVERT(varchar(5),@HasAlterAnySchema),'NULL')));
            INSERT @Check VALUES ('ALTER ANY ROLE permission', CASE WHEN @HasAlterAnyRole=1 THEN 'PASS' ELSE 'FAIL' END, CONCAT('Effective permission=',COALESCE(CONVERT(varchar(5),@HasAlterAnyRole),'NULL')));
        END TRY
        BEGIN CATCH
            INSERT @Check VALUES ('Target database inspection', 'FAIL', ERROR_MESSAGE());
        END CATCH;
    END
END;

SELECT CheckName, Result, Detail FROM @Check ORDER BY CASE Result WHEN 'FAIL' THEN 0 WHEN 'PASS' THEN 1 ELSE 2 END, CheckName;
SELECT CASE WHEN EXISTS(SELECT 1 FROM @Check WHERE Result='FAIL') THEN 'FAIL' ELSE 'PASS' END AS OverallResult;
IF EXISTS(SELECT 1 FROM @Check WHERE Result='FAIL') THROW 51001,'AIAF database preflight failed.',1;
'@

$query = $query.Replace('__TARGET_DATABASE__', $escapedDatabase)

$tempSql = Join-Path ([System.IO.Path]::GetTempPath()) ('aiaf-preflight-' + [guid]::NewGuid().ToString('N') + '.sql')
try {
    [System.IO.File]::WriteAllText($tempSql, $query, [System.Text.UTF8Encoding]::new($false))
    $argsList = @('-S', $ServerInstance, '-E', '-b', '-r', '1', '-W', '-w', '4096', '-i', $tempSql)
    if ($TrustServerCertificate) { $argsList += '-C' }
    & sqlcmd @argsList
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { exit 1 }
    exit 0
}
finally {
    Remove-Item -LiteralPath $tempSql -Force -ErrorAction SilentlyContinue
}
