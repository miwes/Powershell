<#
.SYNOPSIS
Module urceny pro logovani do souboru CSV, konzole
#>

Set-StrictMode -Version Latest

[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
[String]$CSVHeader = 'Time;Type;Message'

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
Funkce kontroluje existenci log file, pokud neexistuje zaloziho a prida na zacatek hlavicku
.Parameter LogFile
Soubor kam se maji informace zaspat. Data jsou vzdy pridany
.Parameter CSVHeader
Hlavicka CSV souboru
#>
Function Private_SetLogFile {
    [CmdletBinding()]Param(
         [Parameter(Mandatory=$true,ValueFromPipeline=$True)]
         [string]$LogFile
        
         ,[Parameter(Mandatory=$true,ValueFromPipeline=$True)]
         [string]$CSVHeader
    )
    If (![System.IO.File]::Exists($LogFile)) {
        $stream = New-Object 'System.IO.StreamWriter' -ArgumentList $logFile, $False
        $stream.WriteLine($CSVHeader)
        $stream.Close()
    }
    Return 0
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
        $LogMessageCSV = $Date + ';' + $type + ';' + $Message
        $LogMessageConsole = $Date + ' -> [' + $type + '] ' + $Message
    }

    PROCESS {
        If($logFile) {
            $ReturnValue = Private_SetLogFile -logFile $logFile -CSVHeader $CSVHeader    
            If($ReturnValue -eq -1) {
                Write-Verbose "Cannot create log file ! - $logFile"
                Return -1
            }
            Try {
                $stream = New-Object 'System.IO.StreamWriter' -ArgumentList $logFile, $True
                $stream.WriteLine($LogMessageCSV)
                $stream.Close()
            }
            Catch {
                Write-Verbose "Cannot append to log file ! - $logFile"
                Return -1
            }
        }
        Write-Verbose $LogMessageConsole
    }

    END {
    }    
}

# exportuj pouze funkce s pomlckou
Export-ModuleMember *-*