<# 
.SYNOPSIS 
    Report updates on server
.DESCRIPTION 
.NOTES 
    Author     : Michal Weis
    Version    : 1.3
        - 1.1 - add info report - cannot find any report logs
        - 1.2 - add Reboot column, change color
        - 1.3 - add mail CC

.LINK 
.EXAMPLE 

#>  

[CmdletBinding()]
Param
(
       [Parameter(Mandatory=$False)] [string]$logPath = \\noman.loc\SYSVOL\noman.loc\scripts\update\log,
       [Parameter(Mandatory=$False)] [int]$day = 2,
       [Parameter(Mandatory=$False)] [string]$mailTo = 'noman@noman.cz,noman@noman.cz',
       [Parameter(Mandatory=$False)] [string]$mailCc = 'it@noman.cz',
       [Parameter(Mandatory=$False)] [string]$mailFrom = 'update_serveru@noman.cz',
       [Parameter(Mandatory=$False)] [string]$SMTP = '192.168.131.4'
       
)

Function Get-LogFile
{
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('Path')]
        [string]$sPathLog,
    
        [Parameter(Mandatory=$true)]
        [Alias('day')]
        [string]$iDay
    )
    
    $fromDate = (Get-Date).AddDays(-$day)
    $toDate = Get-Date
    $oLogFile = Get-ChildItem -Path $logpath -Filter *.txt | Where-Object { $_.CreationTime -ge $fromDate -and $_.CreationTime -le $toDate }
    Return $oLogFile
}

Function Get-LogContent
{
    Param(
        [Parameter(Mandatory=$true)]
        [object]$File
    )
    
    $logData = @()
    
    ForEach($oFile in $File)
    {
        $sContent = Import-CSV $oFile.FullName -Header Date,Hostname,Status,Value -Delimiter ';'
        ForEach ($Row In $sContent)
        {
             $oTemp =  New-Object -TypeName PSObject
             $oTemp | Add-Member -MemberType NoteProperty -Name Date -Value $Row.Date
             $oTemp | Add-Member -MemberType NoteProperty -Name Hostname -Value $Row.Hostname
             $oTemp | Add-Member -MemberType NoteProperty -Name Status -Value $Row.Status
             $oTemp | Add-Member -MemberType NoteProperty -Name Value -Value $Row.Value
             $logData += $oTemp        
        }
    }
    Return $logData
}

Function Get-HtmlReport
{
    Param(
        [Parameter(Mandatory=$true)]
        [object]$Data,
        
        [Parameter(Mandatory=$true)]
        [Alias('day')]
        [string]$iDay
    )
    
    $fromDate = (Get-Date).AddDays(-$day)
    $toDate = Get-Date
    
    $sHTML = "<html><head><title>Report update server</title></head>"
    $sHTML += "<style>BODY{font-family: Arial; font-size: 10pt;}"
    $sHTML += "TABLE{border: 1px solid black; border-collapse: collapse;}"
    $sHTML += "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
    $sHTML += "TD{border: 1px solid black; padding: 5px; }"
    $sHTML +=  "</style>"    
    $SHTML += "<body>"
    $sHTML += "<h3><Font face='Arial'>Report install updatu server: $fromDate - $toDate</font></h3>"
    $sHTML += "<hr>"
    $sHTML += "<TABLE style='font-weight:normal; border-collapse: collapse'>"
    $SHTML += "<TR style='font-family:Arial'>
                <TH style='font-weight:bold;text-align:left'>Hostname</TH>
                <TH style='font-weight:bold;text-align:right'>Installed updates</TH>
                <TH style='font-weight:bold;text-align:right'>Error</TH>
                <TH style='font-weight:bold;text-align:right'>Reboot</TH></TR>"
            
    ForEach ($server In ($logData | group-object hostname))
    {
        $iNumInstall = ($logData | Where {($_.Hostname -eq $server.name) -and ($_.Status -eq 'Installed')} | Measure).Count
        $iNumError = ($logData | Where {($_.Hostname -eq $server.name) -and ($_.Status -eq 'Error')} | Measure).Count
        If ((($logData | Where {($_.Hostname -eq $server.name) -and ($_.Status -eq 'Reboot')} | Measure).Count) -ne 0)
        {
            $iReboot = 'Yes'
        }
        else 
        {
            $iReboot = 'No'
        }


        
        If ($iNumError -gt 0)
        {
            $sHTML += "<TR style='background-color:#FFBB99;color:BLACK'>"
        }
        Else
        {
            $sHTML += "<TR style='color:BLACK'>"
        }
        
        $sHTML += "<TD style='font-weight:normal;text-align:left'>$(($server.name).ToUpper())</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:right'>$iNumInstall</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:right'>$iNumError</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:right'>$iReboot</TD>"
        $sHTML += "</TR>"
    }
    
    $sHTML += "</TABLE>"
    $sHTML += "</body>"
    Return $sHTML
}

Function Send-Email
{
    Param
    (
                   [Parameter(Mandatory=$True,Position=1)] [string]$From,
        [Parameter(Mandatory=$True,Position=2)] [string]$To,
        [Parameter(Mandatory=$True,Position=3)] [string]$Cc,
        [Parameter(Mandatory=$True,Position=4)] [string]$Subject,
        [Parameter(Mandatory=$True,Position=5)] [string]$Body,
        [Parameter(Mandatory=$True,Position=6)] [string]$SMTPServer
    )

    $message = New-Object System.Net.Mail.MailMessage $from, $to
    $message.cc.Add($cc)
    $message.Subject = $subject
    $message.IsBodyHtml = $true
    $message.Body = $body
    
    $email = New-Object system.net.mail.smtpClient($SMTPserver)
    $email.Send($message)
}

$file = Get-LogFile -Path $logPath -day $day
If ($file.Count -ne 0)
{
    $logData = Get-LogContent -File $file
    $sHTML= Get-HtmlReport -Data $logData  -Day $day
    If (($logData | group-object status | Where {$_.name -eq 'error'} | Select -ExpandProperty Count) -gt 0)
    {
        $sSubject = "[Error] Report update serveru : $($file.Count) server(s)"
    }
    Else
    {
        $sSubject = "[Success] Report update serveru : $($file.Count) server(s)"    
    }
}
Else 
{
    $sHTML = "Cannot find any report logs." 
    $sSubject = "[Info] Report update serveru"
}
Send-Email -From $mailFrom -To $mailTo -Cc $mailCc -Subject $sSubject -Body $sHTML -SMTPServer $SMTP
