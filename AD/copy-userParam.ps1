<#
.SYNOPSIS
    set AD attribute from one Ad to another AD :)
.DESCRIPTION
.NOTES
.LINK
.EXAMPLE
#>

<# TODO

#>

[CmdletBinding()]Param (
    [Parameter(Mandatory=$False)]  [string]$attrFileCSV = "C:\temp\users.csv"
    ,[Parameter(Mandatory=$False)]  [string]$attrLogPath = "C:\temp\"
    ,[Parameter(Mandatory=$False)]  [string]$attrSourceDC = 'dc1'
    ,[Parameter(Mandatory=$False)]  [string]$attrTargetDC = 'dc2'
    ,[Parameter(Mandatory=$False)]  [hashtable]$attrParam = @{
        'telePhonenumber' = 'telePhonenumber'
        'Mobile' = 'Mobile'
        'facsimileTelephoneNumber' = 'facsimileTelephoneNumber'
        'Description' = 'Description'
        'Streetaddress' = 'Streetaddress'
        'postalcode' = 'postalcode'
        'extensionAttribute2' = 'extensionAttribute2'
        'extensionAttribute3' = 'extensionAttribute3'
        'extensionAttribute4' = 'extensionAttribute4'
        'extensionAttribute5' = 'extensionAttribute5'
        'extensionAttribute6' = 'extensionAttribute1'
    }
)

# inicialization
Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
$Error.Clear()

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
        $message = "$TimeStamp;" +  $($attrText).ToString()
        Switch ($attrType) {
            'Info'      {Write-Host $message }
            'Warning'   {Write-Host $message -ForegroundColor yellow}
            'Error'     {Write-Host $message -ForegroundColor red}
        }
    }
    If ($attrExit -or $attrType -eq 'Error') {
        Write-Host "$TimeStamp;Stop"
        "$TimeStamp;$attrType;Stop" | Out-File -FilePath $attrFile -Append -ErrorAction Stop
        Exit
    }
}

$DateLog = Get-Date -Format ('yyyyMMdd')
$FileLog = "$attrLogPath\$($DateLog)_main.log"

# import users
$Users = Import-Csv -Path $attrFileCSV -Delimiter ','

ForEach ($User In $Users) {

    Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Try find source user $($user.SourceName)"

    # try find source user
    Try {
        $sourceUser = Get-ADUser $($user.SourceName) -Server $attrSourceDC -Properties *
    } Catch {
        Add-Log -attrFile $FileLog -attrType 'Warning' -attrText "Cannot find $($user.SourceName);$($Error[0])"
        Continue
    }

    # try find target user
   Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Try find target user $($user.TargetSAM)"
    Try {
        $targetUser = Get-ADUser $($user.TargetSAM) -Server $attrTargetDC -Properties *
    } Catch {
        Add-Log -attrFile $FileLog -attrType 'Warning' -attrText "Cannot find $($user.TargetSAM);$($Error[0])"
        Continue
    }

    # set parameters
    foreach ($param in $attrParam.GetEnumerator()) {

        $sourceParam = $sourceUser.$($param.Name)
        $targetParam = $targetUser.$($param.Name)

        if ($sourceParam) {
            
            Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Set $($param.Value) on user $($user.TargetSAM) from '$targetParam' => '$sourceParam'"

            If ($sourceParam -is [System.Collections.CollectionBase]) {
                $sourceParam = $sourceParam -split ','
            }
        
            Try {
                Set-ADObject $targetUser -Replace @{$($param.Value) = $sourceParam} -ErrorAction Stop -whatif
            } Catch {
                Add-Log -attrFile $FileLog -attrType 'Warning' -attrText "Cannot set $($user.TargetSAM) $sourceParam;$($Error[0])"
            }
        }
    }
}