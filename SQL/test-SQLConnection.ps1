<#
.SYNOPSIS
    Skritpt na testovani dostupnosti SQL databazi
.DESCRIPTION
.NOTES
.LINK
.EXAMPLE
.PARAMETER foo
.PARAMETER bar
#>

<# TODO

#>

[CmdletBinding()]Param (
     [Parameter(Mandatory=$False)] [Alias("LogFile")] [string]$attrLogPath = 'c:\temp\log\'
    ,[Parameter(Mandatory=$False)] [Alias("SQLServer")] [string]$attrSQLServer = 'localhost'
    ,[Parameter(Mandatory=$False)] [Alias("SQLDatabases")] [array]$attrDatabases = @('master','model','MM_Kompetence')
)

# inicialization
Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
$Error.Clear()

#region function
Function Add-Log () {
    <#
    .SYNOPSIS
    Add data to log file

    #>

    [CmdletBinding()] Param (
        [Parameter(Mandatory = $false,valueFromPipeline=$true)] 
        [string]$attrFile
        
        ,[Parameter(Mandatory = $false,valueFromPipeline=$true)] 
        [string]$attrText
        
        ,[Parameter(Mandatory = $false,valueFromPipeline=$true)]  
        [ValidateSet("Info", "Warning", "Error")]
        [string]$attrType
        
        ,[Parameter(Mandatory = $false,valueFromPipeline=$true)] 
        [switch]$attrExit = $false

        ,[Parameter(Mandatory = $false,valueFromPipeline=$true)] 
        [switch]$attrOutput = $false
    )

    <# moznost vypnuti vystupu do konzole#>
    $attrOutput = $true

    $TimeStamp = Get-Date
   
    If ($attrFile) {
        Try {
            "$TimeStamp;$attrType;$attrText" | Out-File -FilePath $attrFile -Append -ErrorAction Stop
        } Catch {
            Return $False
        }
    }

    If ($attrOutput) {
        $message = "$TimeStamp;$attrType;" +  $($attrText).ToString()
        Switch ($attrType) {
            'Info'      {Write-Host $message }
            'Warning'   {Write-Host $message -ForegroundColor yellow}
            'Error'     {Write-Host $message -ForegroundColor red}
        }
    }

    If ($attrExit -or $attrType -eq 'Error') {
        Write-Host "$TimeStamp; End"
        If ($attrFile) {
            "$TimeStamp;End" | Out-File -FilePath $attrFile -Append 
        }
        Exit
    }
}

Function New-SQLConnection {
    [CmdletBinding()]
	param(
		[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
		[string]$SQLServer
    )

   Try {
        $ConnectionString = "Data Source=$SQLServer;Integrated Security=SSPI"
        $Connection = New-Object System.Data.SqlClient.SQLConnection($ConnectionString)
        $Connection.Open()
        
        Return $Connection
        
    } Catch {
        Return -1
        Write-Warning $Error[0]
    }
}

Function Get-SQLQuery {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory= $True,ValueFromPipeline= $True)] 
        [object]$SQLConnection

        ,[Parameter(Mandatory= $True,ValueFromPipeline= $True)] 
        [string]$SQLQuery
    )

    Try {
        $Command = New-Object system.data.sqlclient.sqlcommand
        $Command.Connection = $SQLConnection
        $Command.CommandText = $SQLQuery
        $Result = $Command.ExecuteReader()
        
        $Datatable = New-Object System.Data.DataTable
        [void]$Datatable.Load($Result) 
        
        $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $Command
        $Dataset = New-Object System.Data.Dataset
        [void]$DataAdapter.Fill($Dataset)
    
        Return $Dataset.Tables[0]
    } Catch {
        #Write-Warning $Error[0]
        Return -1
    }
}

Function Close-SQLConnection {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory= $True,ValueFromPipeline= $True)] 
        [object]$SQLConnection
    )

    Try {
        $SQLConnection.close()
    } Catch {
        Write-Warning $Error[0]
    }
}
#endregion

# set file log
$DateLog = Get-Date -Format ('yyyyMMdd')
$FileLog = "$attrLogPath\$($DateLog)_SQLTestConnection.log"
# start log
If ((Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Start") -eq $False) {
    Write-Warning "Cannot write to log file $FileLog"
    Exit
}

# connect to SQL servers
Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Trying connect to $attrSQLServer"
$SQLConnection = New-SQLConnection -SQLServer $attrSQLServer 
If ($SQLConnection -eq -1) {
    Add-Log -attrFile $FileLog -attrType 'Error' -attrText "Cannot connect to SQL $attrSQLServer : $Error[0]"
    Add-Log -attrFile $FileLog -attrType 'Info' -attrText 'End'
    Exit
}
Add-Log -attrFile $FileLog -attrType 'Info' -attrText "[OK] Trying connect to $attrSQLServer"

# test QUERY
ForEach ($database In $attrDatabases) {
    Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Trying switch to database $database"
    $SQLQuery = "
        USE $database
        SELECT 1
    "
    $Result = Get-SQLQuery -SQLConnection $SQLConnection -SQLQuery $SQLQuery
    If ($Result -eq -1) {
        Add-Log -attrFile $FileLog -attrType 'Warning' -attrText "Not possible switch to database $database;$($Error[0])"
    } Else {
        Add-Log -attrFile $FileLog -attrType 'Info' -attrText "[OK] Trying switch to database $database"
    }
}


# disconnect to SQL servers
Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Trying disconnect from $attrSQLServer"
$SQLConnection = Close-SQLConnection -SQLConnection $SQLConnection 
If ($SQLConnection -eq -1) {
    Add-Log -attrFile $FileLog -attrType 'Error' -attrText "Cannot disconnect from SQL $attrSQLServer : $Error[0]"
    Add-Log -attrFile $FileLog -attrType 'Info' -attrText 'End'
    Exit
}
Add-Log -attrFile $FileLog -attrType 'Info' -attrText "[OK] Trying disconnect from $attrSQLServer"
