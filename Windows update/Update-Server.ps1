<# 
.SYNOPSIS 
    Install updates on server
.DESCRIPTION 
.NOTES 
    Author     : Michal Weis
    Version    : 1.0
                 1.1   - split function
                 1.2   - Add comments, add argument IsAssigned=1
                 1.3   - Change info, add logging, automatic reboot choice
                 1.4   - Add detect run as admin, add hostname to log
                 1.4.1 - Add log record when start script 
                 1.4.2 - Change error log file
		 1.4.3 - fix some errors
.LINK 
.EXAMPLE 
    .\update-Server.ps1
#>  

[CmdletBinding()]
Param
(
       [Parameter(Mandatory=$False,Position=0)] [string]$logPath = "\\pasvdcext01\SYSVOL\test.ext\scripts\logs",
       [Parameter(Mandatory=$False,Position=1)] [ValidateSet("true","false")] [string]$reboot = 'true'
)

Function Get-RunAs
{
    
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Return $False
    }
    Else
    {
        Return $True
    }
}

Function Get-LogName
{
    Param
    (
        [Parameter(Mandatory=$false, Position=0)] [string]$filePath
    )
    
    If ($filePath)
    {
        If ($filePath.Substring($filePath.Length-1,1) -ne '\')
        {
            $filePath += '\'
        }
        $Date = Get-Date -format ddMMyy
        $LogName = $filePath + $env:computername + '_' + $date + '.txt'
        # check exist path
        If (!(Test-Path -Path $filePath))
        {
            Write-Warning "[Error] $filePath is not available. Logfile isn't creating."
            $LogName = ""
        }
    }
    Else
    {
        $LogName = ""
    }
    
    Return $LogName
}

Function Add-Log
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)] [string]$filePath,
        [Parameter(Mandatory=$true, Position=1)] [string]$text
    )
    
     Add-Content -Path $filePath -Value "$(get-date);$env:computername;$text"
}

Function Get-Updates
{
    Param
    (
        [Parameter(Mandatory=$False, Position=0)] [string]$logFile
    )
      
    Write-Progress -Activity "[Info] Search updates ... $env:ComputerName" -Status "."
    $oUpdateSession = New-Object -com Microsoft.Update.Session
    $oSearcher = $oUpdateSession.CreateupdateSearcher()
    Try
    {
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa386526(v=vs.85).aspx
        $Updates = $oSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0 and IsAssigned=1")
    }
    Catch
    {
        Write-Warning "[Error] " $Error[0]
        If ($logfile)
        {
            Add-Log -FilePath $logFile -Text "Error;$($Error[0])"
        } 
        Exit
    }

    # $Critical = $Updates.updates | where { $_.MsrcSeverity -eq "Critical" }
    # $important = $Updates.updates | where { $_.MsrcSeverity -eq "Important" }
    # $other = $Updates.updates | where { $_.MsrcSeverity -eq $null }

    Write-Host "[Info] Number of detected updates: $($Updates.updates.count)"
    # log write
    If ($logfile)
    {
        Add-Log -FilePath $logFile -Text "Info;Number of detected updates: $($Updates.updates.count)"
    } 

    Return $Updates
}

Function Receive-Updates
{
    Param
    (
        [Parameter(Mandatory=$True, Position=0)] [object]$Updates,
        [Parameter(Mandatory=$False, Position=1)] [string]$logFile
    )

    $oUpdateSession = New-Object -com Microsoft.Update.Session
    $UpdateCollection = New-Object -ComObject Microsoft.Update.UpdateColl
    $downloader = $oUpdateSession.CreateUpdateDownLoader()
    $i = 1	
    
    ForEach($Update in $Updates.updates)
    {      
        Write-Progress -Activity "[Info] Download updates ... $env:ComputerName" -Status "$i .. $($Updates.updates.count)" -PercentComplete (($i++/$($Updates.updates.count)) *100) 
        $UpdateCollection.Add($update) | out-null
        Write-Host "[Download] KB$($update.KBArticleIDs) - $($update.Title)"
        # log write
        If ($logfile)
        {
            Add-Log -FilePath $logFile -Text "Download;KB$($update.KBArticleIDs) - $($update.Title)"
        }
        If (!($update.isDownloaded))
        {
            # download update
            Try
            {
                $downloader.Updates = $UpdateCollection 
                $downloader.Download() | out-null
                $UpdateCollection.Clear()
            }
            Catch
            {
                Write-Warning "[Error] Download KB$($update.KBArticleIDs)" $Error[0]
                Add-Log -FilePath $logFile -Text "Error; KB$($update.KBArticleIDs) $($Error[0])"
            }
        }
    }
}

Function Install-Updates
{
    Param
    (
        [Parameter(Mandatory=$True, Position=0)] [object]$Updates,
        [Parameter(Mandatory=$False, Position=1)] [string]$logFile
    )
       
    $RebootRequired = $false
    $oUpdateSession = New-Object -com Microsoft.Update.Session
    $installs = New-Object -ComObject Microsoft.Update.UpdateColl
    $installer = $oUpdateSession.CreateUpdateInstaller()
    $i = 1

    ForEach ($update in $Updates.updates)
    {
        Write-Progress -Activity "[Info] Install updates ... $env:ComputerName" -Status "$i .. $($Updates.updates.count)" -PercentComplete (($i++/$($Updates.updates.count)) *100)
        Write-Host "[Install] KB$($update.KBArticleIDs) - $($update.Title)"
        Try
        {
            If ($update.EulaAccepted -eq $False)
            {
                $update.AcceptEula()   
            }

            $installs.Add($update) | out-null
            $installer.Updates = $installs
            $installresult = $installer.Install()
            
            If ($installresult.RebootRequired) 
            {
                $RebootRequired = $true
            }
            If ($installresult.Hresult -ne 0)
            {
                Write-Warning "[Error] Install KB$($update.KBArticleIDs) - $($update.Title)"
                If ($logfile)
                {
                    Add-Log -FilePath $logFile -Text "Error;KB$($update.KBArticleIDs) - $($update.Title) $($Error[0])"
                } 
            }
            Else
            {
                If ($logfile)
                {
                    Add-Log -FilePath $logFile -Text "Installed;KB$($update.KBArticleIDs) - $($update.Title)"
                }    
            }
        }
        Catch
        {
            Write-Warning "[Error] Install KB$($update.KBArticleIDs) - $($update.Title)" $Error[0]
            If ($logfile)
            {
                Add-Log -FilePath $logFile -Text "Error;KB$($update.KBArticleIDs) - $($update.Title) $($Error[0])"
            } 
        } 
               

        $installs.Clear()
    }
    return $RebootRequired 
}

Function Get-Reboot
{
    If (Test-Path -path "hklm:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")
    {
        # reboot is required
        Return $true
    }
    Else
    {
        Return $false   
    }
}

# detect RunAs Administrator
If (!(Get-RunAs))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Exit
}

# set culture
[threading.thread]::CurrentThread.CurrentCulture = 'en-US'

# create log file name
$LogFile = Get-LogName -filePath $logPath

If ($logfile)
{
	Add-Log -FilePath $logFile -Text "Info;Start"
} 


# check reboot
If (Get-Reboot)
{
    Write-Host "[Info] Computer needs reboot"
    If ($logfile)
    {
        Add-Log -FilePath $logFile -Text "Info;Computer needs reboot"
    } 
    # if reboot yes
    if ($reboot.ToLower() -eq 'true')
    {
        If ($logfile)
        {
            Add-Log -FilePath $logFile -Text "Reboot;Computer now rebooting"
        }
        # reboot
        & shutdown /f /r /t 10
        Exit
    }
}

# get updates
Add-Log -FilePath $logFile -Text "Info;Start search updates"
$oUpdates = (Get-Updates -LogFile $LogFile)
If ($oUpdates.Updates.Count -eq 0)
{
    Exit
}
# download updates
Receive-Updates -Updates $oUpdates -LogFile $LogFile

# install updates
$RebootRequired = Install-Updates -Updates $oUpdates -LogFile $LogFile
If ($RebootRequired  -eq $true)
{
	Write-Host "[Info] Computer needs reboot"
    If ($logfile)
    {
        Add-Log -FilePath $logFile -Text "Info;Computer needs reboot"
    } 
    # if reboot yes
    if ($reboot.ToLower() -eq 'true')
    {
        If ($logfile)
        {
            Add-Log -FilePath $logFile -Text "Reboot;Computer now rebooting"
        }
        # reboot
        & shutdown /f /r /t 10
    }
}
Else
{
	Write-Host "[Info] No restart required"
    If ($logfile)
    {
        Add-Log -FilePath $logFile -Text "Info;No restart required"
    } 
}

If ($logfile)
{
	Add-Log -FilePath $logFile -Text "Info;End"
} 
