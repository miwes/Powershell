<#
.SYNOPSIS
    Shutdown Hyper-V
.NOTE
    Author:     Michal Weis
    SVN   : 	$Revision: 18 $
                $Date: 2017-11-23 20:02:55 +0100 (Thu, 23 Nov 2017) $

    23.11.2017 - Start

.EXAMPLE
    WhatIf mode (nothing shutdowns)
    .\Shutdown-HyperV.ps1 -WhatIf

    Normal mode with verbose information
    .\Shutdown-HyperV.ps1 -Verbose

    Normal mode
    .\Shutdown-HyperV.ps1
#>

<#
TODO: 

#>
[CmdletBinding()] Param(
    [Parameter(Mandatory=$false)] [Alias("ConfigFile")] [String]$ParamFile = "$PWD\config.txt"
    ,[Parameter(Mandatory=$false)] [Switch]$WhatIf
)

Set-StrictMode -Version latest

#Region Function
function Get-Config () {
    [CmdletBinding()] Param(
        [Parameter(Mandatory=$true)]
        [string]$pConfigFile
    )

    If (![System.IO.File]::Exists($pConfigFile)) {
       Write-Warning "Cannot load CSV $pConfigFile"
       Return -1
    }

    $Config = @{}
    Import-Csv -Path $pConfigFile -Delimiter '=' | ForEach-Object {$Config[$_.Setting] = $_.Value}
    Return $Config
}
function Add-Log () {
    [CmdletBinding()] Param 
    (
        [Parameter(Mandatory = $true,valueFromPipeline=$true)] $File
        ,[Parameter(Mandatory = $true,valueFromPipeline=$true)] $Text
    )

    $TimeStamp = Get-Date
    Add-Content -Path $File -Value "$TimeStamp;$Text" -ErrorAction SilentlyContinue
    Write-Verbose $Text
}
Function Add-Module {
    [CmdletBinding()] Param
   (
       [Parameter(Mandatory=$true)][Alias('Module')][string]$sModule 
   )

   If (Get-Module -ListAvailable -Name $sModule) 
   {
       Import-Module $sModule
       Return $True
   }
   Else 
   {
       Write-Warning "[Error] fn. Load-Module : Module $sModule neexistuje."
       Return $False
   }
}

Function Get-ShutdownVM {
    [CmdletBinding()] Param
    (
        [Parameter(Mandatory=$true)][object]$VMs
        ,[Parameter(Mandatory=$true)][string]$Hypervizor
        ,[Parameter(Mandatory=$true)][int]$TimeOut
        ,[Parameter(Mandatory=$true)][string]$FileLog
    )
    
    ForEach($VM In $VMs)  {
        Add-Log -File $FileLog -Text  "Info;Shutdown $VM"
        $job = Stop-VM -ComputerName $Hypervizor -Name $VM -AsJob
    }
    
    
    $MaxTime = (get-date).AddMinutes($TimeOut)
    While (((get-date) -lt $MaxTime) -and (Get-VM -ComputerName $Hypervizor | Where-Object {$_.State -ne 'Off' -and $_.name -in $VMs})) {
        Write-Verbose 'Waiting for shutdown VMs'
        Start-Sleep -Seconds 5   
    }
}
#EndRegion Function

Write-Verbose "Load config data "
$Config = Get-Config -pConfigFile $ParamFile
If ($Config -eq -1) {
    Exit
}
$DateLog = Get-Date -Format ('yyyyMMdd')
$FileLog = "$($Config['LogFilePath'])\$($DateLog)_shutdown.log"

Add-Log -File $FileLog -Text  "Start;"

#load modulue
If (!(Add-Module -Module 'Hyper-V'))
{
   Add-Log -File $FileLog -Text 'Error;Cannot load Hyper-V powershell modul'
   Add-Log -File $FileLog -Text "Stop;"
   Exit;
}

# load VM all
Add-Log -File $FileLog -Text "Info;Get all VM from $($Config['HyperV'])"
Try {
    $oAllVM = Get-VM -ComputerName $Config['HyperV'] -ErrorAction Stop
} Catch {
    Add-Log -File $FileLog -Text "Error;Cannot get VM from $($Config['HyperV'])"
    Add-Log -File $FileLog -Text "Stop;"
    Exit;
}

# load all tiers from CSV
$Tiers = $Config.Keys  | Where-Object {$_ -like 'tier*'} | Sort-Object

# get all vm from define tiers
$TierVMS = ForEach ($TierVM In $Tiers) { 
    $Config[$TierVM].Split(',') 
}

$TierVMS += $Config['ExcludeVM'].Split(',')

# get tier0 vm
$Tier0 = $oAllVM | Where-Object {$_.Name -notin $TierVMS} | Select-Object -ExpandProperty Name
$AllTiersVM = @()
$AllTiersVM += [system.String]::Join(',',$Tier0)

# join all VM from tiers
ForEach ($Tier In $Tiers) {
    $AllTiersVM += $Config[$Tier]
}

Add-Log -File $FileLog -Text "Info;Start shutdown process"
# start shutdown process
ForEach ($Tier In $AllTiersVM) {
    If ($WhatIf) {
        Write-Host "[WhatIf] Shutdown VMs: $Tier"
    } Else {
        Get-ShutdownVM -VMs $Tier.Split(',') -Hypervizor $Config['HyperV'] -TimeOut $Config['Timeout'] -FileLog $FileLog
    }
}

Add-Log -File $FileLog -Text  "Stop;"