<#
.SYNOPSIS
    Demo config file
.DESCRIPTION
.NOTES

.LINK
.EXAMPLE
.PARAMETER foo
.PARAMETER bar
#>


[CmdletBinding()] Param(
   [Parameter(Mandatory=$false)]   $attrConfigFile = "$PWD\configFile.txt"
   ,[Parameter(Mandatory=$false)]   $attrLogPath = '.\'
)

# inicialization
Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
$Error.Clear()

#region function
Function get-Config () {

    [CmdletBinding()] Param(
        [Parameter(Mandatory=$true)] [string]$attrConfigFile
    )

    If (![System.IO.File]::Exists($attrConfigFile)) {
       Write-Warning "Nelze nahrat konfiguracni CSV $attrConfigFile"
       Return -1
    }

    $Config = @{}
    Get-Content $attrConfigFile | Select-String '^[^#]' | ConvertFrom-Csv -Delimiter '=' | ForEach-Object {$Config[$_.Setting] = $_.Value}
    Return $Config
}

Function Add-Log () {
    <#
    .SYNOPSIS
    Add data to log file

    #>

    [CmdletBinding()] Param 
    (
         [Parameter(Mandatory = $true,valueFromPipeline=$true)] [string]$attrFile
        ,[Parameter(Mandatory = $true,valueFromPipeline=$true)] [string]$attrText
        ,[Parameter(Mandatory = $false,valueFromPipeline=$true)] [switch]$attrVerbose
    )

    $TimeStamp = Get-Date
    Try {
        "$TimeStamp;$attrText" | Out-File -FilePath $attrFile -Append -ErrorAction Stop
    } Catch {
        Return $False
    }
    If ($attrVerbose) {
        Write-Verbose $($attrText).ToString()
    }
}
#endregion function

$DateLog = Get-Date -Format ('yyyyMMdd')
$FileLog = "$attrLogPath\$($DateLog)_main.log"
# start log
If ((Add-Log -attrFile $FileLog -attrText "Inf;Start") -eq $False) {
    Add-Log -attrFile $FileLog -attrText "Error;Cannot write to log file $FileLog" -attrVerbose
    Exit
}

Add-Log -attrFile $FileLog -attrText "Inf;Nahravam konfiguracni data" -attrVerbose 
$Config = Get-Config -attrConfigFile $attrConfigFile
If ($Config -eq -1) {
    Exit
}

Write-Host "Existuji promenna URL:" -BackgroundColor Black
$Config['URL'] 
Write-Host "Existuji promenna PCData:" -BackgroundColor Black
$Config['PCData']
(Add-Log -attrFile $FileLog -attrText "Inf;End") 