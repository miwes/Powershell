<#
.SYNOPSIS
    Moduly pro praci s SQL a ODBC
    Version 
        1.0   - prvni release
        1.0.1 - change New-SQLConnection
.DESCRIPTION
.NOTES
#>

$global:ErrorActionPreference = 'Stop'

Function New-ODBCConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [string]$attrODBCName
    )

    Try {
        $ConnectionString = "DSN=$attrODBCName"
        $Connection = New-Object System.Data.Odbc.OdbcConnection($ConnectionString)
        $Connection.Open()
        
        Return $Connection
        
    }
    Catch {
        Return -1
        Write-Warning $Error[0]
    }
}

Function Close-ODBCConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]  [object]$attrODBConnection
    )

    Try {
        $attrODBConnection.close()
        Return $true
    }
    Catch {
        Write-Warning $Error[0]
        Return $false
    }
}

Function Get-ODBCQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]  [object]$attrODBCConnection
        , [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [string]$attrQuery
        , [Parameter(Mandatory = $False, ValueFromPipeline = $True)] [ValidateSet('Scalar', 'Reader')] [string]$attrTypeQuery = 'Scalar'
    )

    Try {
        $Command = New-Object System.Data.Odbc.OdbcCommand
        $Command.Connection = $attrODBCConnection
        $Command.CommandText = $attrQuery
        If ($attrTypeQuery -eq 'Scalar') {
            $Result = $Command.ExecuteScalar()
        }
        ElseIf ($attrTypeQuery -eq 'Reader') {
            $Result = $Command.ExecuteReader()
        }
        Return $Result
    }
    Catch {
        Return -999
    }
    Finally {
        $Command.Dispose()
        If ($attrTypeQuery -eq 'Reader') {
            $Result.Dispose()
        }
    }
}

Function New-SQLConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)] [string]$attrSQLServer
        , [Parameter(Mandatory = $False, ValueFromPipeline = $True)] [string]$attrDBName
        , [Parameter(Mandatory = $False, ValueFromPipeline = $True)] [string]$attrConnectionString
    )

    Try {
        If ($attrConnectionString) {
            $ConnectionString = $attrConnectionString
        } 
        Else {
            $ConnectionString = "Data Source=$attrSQLServer;Integrated Security=SSPI;Initial Catalog=$attrDBName"
        }
        $global:ErrorActionPreference = 'Continue'
        $Connection = New-Object System.Data.SqlClient.SQLConnection($ConnectionString)
        $Connection.Open()
        
        Return $Connection
        
    }
    Catch {
        Return $False
    }

}

Function Get-SQLQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]  [string]$attrSQLConnection
        , [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [string]$attrSQLQuery
        , [Parameter(Mandatory = $False, ValueFromPipeline = $True)] [ValidateSet('Scalar', 'Reader')] [string]$attrTypeQuery = 'Scalar'
    )
    
    # try connect to SQL
    $SQLConnection = New-SQLConnection -attrConnectionString $attrSQLConnection
    If ($SQLConnection -eq $False) {
        Return $False
    }

    Try {
        $Command = New-Object system.data.sqlclient.sqlcommand
        $Command.Connection = $SQLConnection
        $Command.CommandText = $attrSQLQuery

        If ($attrTypeQuery -eq 'Scalar') {
            $Result = $Command.ExecuteScalar()
        }
        ElseIf ($attrTypeQuery -eq 'Reader') {
            $Result = $Command.ExecuteReader()
        }
        Return $Result
    }
    Catch {
        Close-SQLConnection -attrSQLConnection $SQLConnection
        Return $false
    }
    Finally {
        $Command.Dispose()
        If ($attrTypeQuery -eq 'Reader') {
            $Result.Dispose()
        }
        Close-SQLConnection -attrSQLConnection $SQLConnection
    }
}

Function Get-SQLQueryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [object]$attrSQLConnection
        , [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [string]$attrSQLQuery
    )

    # try connect to SQL
    $SQLConnection = New-SQLConnection -attrConnectionString $attrSQLConnection
    If ($SQLConnection -eq $False) {
        Return $False
    }


    Try {
        $Command = New-Object system.data.sqlclient.sqlcommand
        $Command.Connection = $SQLConnection
        $Command.CommandText = $attrSQLQuery
        $Result = $Command.ExecuteReader()
        
        $Datatable = New-Object System.Data.DataTable
        [void]$Datatable.Load($Result) 
        
        $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $Command
        $Dataset = New-Object System.Data.Dataset
        [void]$DataAdapter.Fill($Dataset)
    
        $JsonData = $Dataset.Tables[0] | ConvertTo-Json

        $Data = $JsonData | ConvertFrom-Json
        $Data.PsObject.Properties.Remove('Table')
        $Data.PsObject.Properties.Remove('ItemArray')
        $Data.PsObject.Properties.Remove('RowError')
        $Data.PsObject.Properties.Remove('RowState')
        $Data.PsObject.Properties.Remove('HasErrors')

        $JsonData = $Data | ConvertTo-Json

        Close-SQLConnection -attrSQLConnection $SQLConnection
        Return $JsonData
    }
    Catch {
        Close-SQLConnection -attrSQLConnection $SQLConnection
        Return $false
    }
}

Function Close-SQLConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [object]$attrSQLConnection
    )

    Try {
        $attrSQLConnection.close()
    }
    Catch {
        Write-Warning $Error[0]
    }
}

Export-ModuleMember *