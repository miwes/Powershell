Function Private_GetDate {
    $Date = $(Get-Date -Format('yyyy-MM-dd HH:mm:ss'))
    Return $Date
}

Function Add-Log {
     [CmdletBinding()]Param(
         [Parameter(Mandatory=$true,ValueFromPipeline=$True)]
         [string]$Message
         
         ,[Parameter(Mandatory=$false,ValueFromPipeline=$True)] 
         [ValidateSet('Information','Warning','Error')]
         [string]$Type = 'Information' 
         
         ,[Parameter(Mandatory=$false,ValueFromPipeline=$True)] 
         [string]$LogFile
     )
    BEGIN {
        $Date = Private_GetDate
        $LogMessage = $Date + ';' + $type + ';' + $Message
    }

    PROCESS {
        If($logFile) {
            $message | out-file $logFile -Append
        }
        Write-Verbose $LogMessage
    }

    END {
    }    
}

# exportuj pouze funkce s pomlckou
Export-ModuleMember *-*