<#
    .SYNOPSIS 
        Export users object from DB
    .DESCRIPTION 
    .NOTES 
        Author     : Michal Weis
        Version    : 1.0

#>

[CmdletBinding()]
Param
(
       [Parameter(Mandatory= $False,ValueFromPipeline= $True)] 
       [string]$SQLServer = "SQL",
       
       [Parameter(Mandatory= $False,ValueFromPipeline= $True)] 
       [string]$DBName = "DB",

       [Parameter(Mandatory= $False,ValueFromPipeline= $True)] 
       [string]$ExportPath = "D:\Backup\"
)

Set-StrictMode -Version 2.0

Function Add-Module
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [Alias('Module')]
        [string]$sModule 
    )


    If (Get-Module -ListAvailable -Name $sModule) 
    {
        Import-Module $sModule
        Return $True
    }
    Else 
    {
        Write-Warning "[Error] fn. Load-Module : Module $sModule does not exist."
        Return $False
    }
}

# nahraj modul
If (!(Add-Module -Module 'SQLPS'))
{
    Write-Warning 'Cannot import module SQLPS'
    Exit;
}

# vytvoreni slozky pro export
$Date = Get-Date -Format d-M-yyyy
$ExportPath = $ExportPath + '\' + $Date + '\' + $DBName
Try
{
    New-Item -ItemType Directory -Force -Path $ExportPath | Out-Null
}
Catch
{
    Write-Warning "Cannot create export path!"
    Exit
}


# seznam uzivatelskych objektu
$Query = 'SELECT [object_id] FROM SYS.objects WHERE type_desc IN (''SQL_STORED_PROCEDURE'',''VIEW'',''SQL_TABLE_VALUED_FUNCTION'',''SQL_SCALAR_FUNCTION'',''SQL_INLINE_TABLE_VALUED_FUNCTION'')'
try 
{
    $UsersObject = Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -Query $Query    
}
catch 
{
    Write-Warning "Cannot connect to SQL $SQLServer"
    Exit    
}


# export uzivatelskych objektu
ForEach ($object In $UsersObject)
{
    Try
    {
        $ObjectName = Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -Query "SELECT sys.schemas.name + '.' + sys.objects.name AS [Name] FROM SYS.objects LEFT JOIN SYS.schemas ON SYS.schemas.schema_id = sys.objects.schema_id WHERE sys.objects.object_id = $($object.object_id)"
        $Definition = Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -Query "SELECT [DEFINITION] FROM sys.sql_modules WHERE [object_id] = $($object.object_id)"
           
        $Definition.DEFINITION | Out-File "$ExportPath\$($ObjectName.name).sql"
    }
    Catch
    {
        Write-Warning "Cannot export $object"
    }
}