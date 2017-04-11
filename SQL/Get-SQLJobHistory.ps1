<# 
.SYNOPSIS 
    Report failure SQL JOB
.DESCRIPTION 
.NOTES 
    Author     : Michal Weis
    Version    : 1.0
			

.LINK 
.EXAMPLE 

#>  

[CmdletBinding()]
Param
(
       [Parameter(Mandatory= $False,ValueFromPipeline= $True)] 
       $SQLServers = @("server1","server2")
       ,[Parameter(Mandatory=$False)] $mailTo = @('user@user.cz','user2@user.cz')
       ,[Parameter(Mandatory=$False)] [string]$mailFrom = 'report@nobydy.cz'
       ,[Parameter(Mandatory=$False)] [string]$SMTP = 'smtp'
)

Set-StrictMode -Version 2.0

Function Add-Module
{
    Param (
        [Parameter(Mandatory=$true)]
        [Alias('Module')]
        [string]$sModule 
    )


    If (Get-Module -ListAvailable -Name $sModule)  {
        Import-Module $sModule
        Return $True
    }
    Else {
        Write-Warning "[Error] fn. Load-Module : Module $sModule does not exist."
        Return $False
    }
}

Function Send-Email
{
    Param
    (
	[Parameter(Mandatory=$True,Position=1)] [string]$From,
        [Parameter(Mandatory=$True,Position=2)] $To,
        [Parameter(Mandatory=$True,Position=3)] [string]$Subject,
        [Parameter(Mandatory=$True,Position=4)] [string]$Body,
        [Parameter(Mandatory=$True,Position=5)] [string]$SMTPServer
    )

    $message = New-Object System.Net.Mail.MailMessage
    $message.from = $from
    $message.Subject = $subject
    $message.IsBodyHtml = $true
    $message.Body = $body
    ForEach($User In $To) {
        $message.to.add($User)
    }
    
    $email = New-Object system.net.mail.smtpClient($SMTPserver)
    $email.Send($message)
}


# nahraj modul
If (!(Add-Module -Module 'SQLPS')) {
    Write-Warning 'Cannot import module SQLPS'
    Exit;
}

  
[string]$Query = 'SELECT
    @@ServerName AS [Hostname]
	,SJ.Name AS [JobName]
	, SJ.description AS [JobDescription]
	,CASE SJH.run_status 
		WHEN 0 THEN ''Failed''
		WHEN 1 THEN ''Successful''
		WHEN 3 THEN ''Cancelled''
		WHEN 4 THEN ''In Progress''
	END AS [LastRunStatus]
	, dbo.agent_datetime(SJH.run_date,SJH.run_time) AS [DateRun]

FROM SysJobs	AS SJ
JOIN SysJobHistory		AS SJH	ON SJH.job_id = SJ.job_id

WHERE 
	-- posledni den
	dbo.agent_datetime(SJH.run_date,SJH.run_time) > CONVERT(date,GETDATE())
	-- je zapnuty
	AND SJ.enabled = 1
	-- prvn step
	AND SJH.step_id = 1
    -- failed job
    AND (SJH.run_status = 0 OR SJH.run_status = 3)

ORDER BY SJH.run_status'
[string]$DBName = 'msdb'
$Results = @()

ForEach ($SQLServer in $SQLServers) {
    Try {
        $Result = @(Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -Query $Query)
        If ($Result.Count -ne 0) {
            $Results += $Result
        }
    } Catch {
        $Result = New-Object -TypeName PSObject -Property @{
            'Hostname' = $SQLServer
            'Jobname' = '-'
            'JobDescription' = '-'
            'LastRunStatus' = 'Cannot connect to SQL server'
            'DateRun' = '-'
        }
        $result
        $Results += $Result
    }
}
$sHTML = "<html><head><title>Backup report</title></head>"
$sHTML += "<style>BODY{font-family: Arial; font-size: 10pt;}"
$sHTML += "TABLE{border: 1px solid black; border-collapse: collapse;}"
$sHTML += "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
$sHTML += "TD{border: 1px solid black; padding: 5px; }"
$sHTML +=  "</style><body>"    
$sHTML += "<h3><Font face='Arial'>SQL jobs report (not success)</font></h3>"
#$sHTML += "<hr>"
$sHTML += "<TABLE style='font-weight:normal; border-collapse: collapse'>"
$SHTML += "<TR style='font-family:Arial;background-color:#A6DBCF'>
            <TH style='font-weight:bold;text-align:left' >Server name</TH>
            <TH style='font-weight:bold;text-align:left' >Job name</TH>
            <TH style='font-weight:bold;text-align:right' >Job description</TH>
            <TH style='font-weight:bold;text-align:center' >Last run status</TH>
            <TH style='font-weight:bold;text-align:center' >Date run</TH>
            </TR>"

ForEach($Line In $Results) {
        $sHTML += "<TR style='color:BLACK'>"
        $sHTML += "<TD style='font-weight:normal;text-align:left'>$($Line.Hostname)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:left'>$($Line.JobName)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:right'>$($Line.JobDescription)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:center'>$($Line.LastRunStatus)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:center'>$($Line.DateRun)</TD>"
        $sHTML += "</TR>"
}
$sHTML += "</TABLE>"
$sHTML += "</body>"

$sSubject = "SQL jobs report (not success)"
Send-Email -From $mailFrom -To $mailTo -Subject $sSubject -Body $sHTML -SMTPServer $SMTP
