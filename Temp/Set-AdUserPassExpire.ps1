<#
.SYNOPSIS
    Set AD User
.DESCRIPTION
.NOTES
.LINK
.EXAMPLE
    # run script
    .\set-aduserpass.ps1 -attrOU "DC=test,DC=local" -Verbose

    # run script with WhatIf mode
    .\set-aduserpass.ps1 -attrOU "DC=test,DC=local" -Verbose -WhatIf
#>



[CmdletBinding()]Param (
    [Parameter(Mandatory=$True)] [Alias("OU")] [string]$attrOU
    ,[Parameter(Mandatory=$False)] [Alias("LogPath")] [string]$attrLogPath = 'c:\log\'
    ,[Parameter(Mandatory=$False)] [Alias("WhatIf")] [switch]$attrWhatIf
)

# inicialization
Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
$Error.Clear()

#Region Function
Function add-Log () {
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
            "$TimeStamp;$attrText" | Out-File -FilePath $attrFile -Append -ErrorAction Stop
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
        Write-Host "$TimeStamp; End"
        If ($attrFile) {
            "$TimeStamp;End" | Out-File -FilePath $attrFile -Append 
        }
        Exit
    }
}

Function Add-Module {
    [CmdletBinding()] Param
   (
       [Parameter(Mandatory=$true)][Alias('Module')][string]$sModule 
   )

   If (Get-Module -ListAvailable -Name $sModule) 
   {
       Import-Module $sModule -Verbose:$false
       Return $True
   }
   Else 
   {
       Write-Warning "[Error] fn. Load-Module : Module $sModule neexistuje."
       Return $False
   }
}
#Endregion Function

# set file log
$DateLog = Get-Date -Format ('yyyyMMdd')
$FileLog = "$attrLogPath\$($DateLog)_main.log"
# start log
If ((Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Start") -eq $False) {
    Write-Warning "Cannot write to log file $FileLog"
    Exit
}

#load module
If (!(Add-Module -Module 'ActiveDirectory')) {
   Add-Log -attrFile $FileLog -attrType 'Error' -attrText 'Cannot load ActiveDirectory powershell modul'
}
If ($attrWhatIf) {
    Add-Log -attrFile $FileLog -attrType 'Info' -attrText "WhatIf mode enable"
}

# get AD users
Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Get users from $attrOU"
Try {
    $objUsers = Get-AdUser -Filter * -SearchBase $attrOU -SearchScope Subtree -Properties pwdlastset,passwordNeverExpires  | Where-Object {$_.pwdlastset -ne 0 -and $_.passwordNeverExpires -ne $true}
} Catch {
    Add-Log -attrFile $FileLog -attrType 'Error' -attrText "Cannot get user from $attrOU;$($Error[0])"
}

# WhatIf mode
If ($attrWhatIf) {
    ForEach ($user In $objUsers) {
        Write-Host "[WhatIf] Set user $user"
    }
} Else {
    # change AD user
    ForEach ($user In $objUsers) {
        Try {
            Add-Log -attrFile $FileLog -attrType 'Info' -attrText "Set user $user"
            Set-AdUser $user -PasswordNeverExpires $True
        } Catch {
            Add-Log -attrFile $FileLog -attrType 'Warning' -attrText "Cannot set user $user;$($Error[0])"
        }
    }
}

Add-Log -attrFile $FileLog -attrType 'Info' -attrText 'End'