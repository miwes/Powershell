<#
.SYNOPSIS
Module urceny pro logovani do souboru, konzole
#>

<#
.SYNOPSIS
Funkce vraci naformatovany datum jako string
#>
Function Private_GetDate {
    [string]$Date = $(Get-Date -Format('yyyy-MM-dd HH:mm:ss'))
    Return $Date
}

<#
.SYNOPSIS
Zapise udalost do souboru, pri pouziti verbose i do konzole
.Parameter Message
Zprava ktera ma byt zapsana do souboru
.Parameter Type
Typ udalosti. Muze byt definovany 3 (Information, Warning, Error). Pokud neni definovane je vychozi Information
.Parameter LogFile
Soubor kam se maji informace zaspat. Data jsou vzdy pridany
#>
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