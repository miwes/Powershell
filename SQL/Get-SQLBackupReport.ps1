<# 
.SYNOPSIS 
    Report backup SQL
.DESCRIPTION 
.NOTES 
    Author     : Michal Weis
    Version    : 1.1
			- 1.1 - format email

.LINK 
.EXAMPLE 

#>  


[CmdletBinding()]
Param
(
       [Parameter(Mandatory=$False)] [object]$SQLServer = @('PASVSQL01\SQL2005','PASVSQL01\SQL2008','PASVSQL01\SQL2012','AX2VAX2012R2\AX2VAX2012R2','PASVNAVSQL01\SQL2014'),
       [Parameter(Mandatory=$False)] [int]$day = 1,
       [Parameter(Mandatory=$False)] [string]$mailTo = 'aaclab@autocont.cz',
       [Parameter(Mandatory=$False)] [string]$mailFrom = 'report@aclab.cz',
       [Parameter(Mandatory=$False)] [string]$SMTP = 'pasvex01'
       
)

Function Get-BackupInfo
{
<#
.Synopsis
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this workflow
.EXAMPLE
    Another example of how to use this workflow
.INPUTS
    Inputs to this workflow (if any)
.OUTPUTS
    Output from this workflow (if any)
.NOTES
    General notes
.FUNCTIONALITY
    The functionality that best describes this workflow
#>

    [OutputType([object])]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [Alias("server")] 
        $SQLServers,
        
        [Parameter(Mandatory=$true, Position=1)]
        $day
        
    )

    $Reports = @()

    ForEach ($Server In $SQLServers)
    {
        $sqlCommand = "
            DECLARE @ReportDay AS DATETIME
            DECLARE @Day AS INT 
	    SET @Day = $day
            SELECT @ReportDay = CAST(DATEADD(day,-@day,GETDATE()) AS DATETIME)
                SELECT
                Database_name
                ,Server_Name
                ,Backup_size
                ,backup_start_date
                ,backup_finish_date
                ,name as backup_file_name
                ,type
            FROM dbo.backupset 
            WHERE
            CAST(backup_start_date AS DATETIME) > @ReportDay
        "
        $connectionString = "Data Source=$server; " + "Integrated Security=SSPI; " + "Initial Catalog=MSDB"
        $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
        $connection.Open()
        
        $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
        $Result = $Command.ExecuteReader()
        $Table = New-Object System.Data.DataTable
        $Table.Load($Result)
        
        ForEach ($Row In $Table)
        {
            $report = New-Object -TypeName PSObject -Property @{
                'Database_Name' = $Row.Database_Name
                'Server_Name' = $Row.Server_name
                'Backup_Size' = $Row.Backup_size
                'backup_start_date' = $Row.backup_start_date 
                'backup_finish_date' = $Row.backup_finish_date
                'backup_file_name' = $Row.backup_file_name
                'type' = $Row.type
            }
            $Reports += $Report
        }
        
        $connection.Close()
    }
    Return $Reports
}

Function Get-HtmlReport
{
<#
.Synopsis
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this workflow
.EXAMPLE
    Another example of how to use this workflow
.INPUTS
    Inputs to this workflow (if any)
.OUTPUTS
    Output from this workflow (if any)
.NOTES
    General notes
.FUNCTIONALITY
    The functionality that best describes this workflow
#>
    Param(
        [Parameter(Mandatory=$false, Position=0)]
        [object]$Data,
                        
        [Parameter(Mandatory=$true, Position=1)]
        $day
    )
    
    #$fromDate = [DateTime]::Today.AddDays(-$day)
    $fromDate = (Get-Date).AddDays(-$day)
    $toDate = Get-Date
    
    $sHTML = "<html><head><title>Backup report</title></head>"
    $sHTML += "<style>BODY{font-family: Arial; font-size: 10pt;}"
    $sHTML += "TABLE{border: 1px solid black; border-collapse: collapse;}"
    $sHTML += "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
    $sHTML += "TD{border: 1px solid black; padding: 5px; }"
    $sHTML +=  "</style><body>"    
    $sHTML += "<h3><Font face='Arial'>Backup report SQL DB za obdobi od $fromDate</font></h3>"
    #$sHTML += "<hr>"
    $sHTML += "<TABLE style='font-weight:normal; border-collapse: collapse'>"
    $SHTML += "<TR style='font-family:Arial;background-color:#A6DBCF'>
                <TH style='font-weight:bold;text-align:left' >Server name</TH>
                <TH style='font-weight:bold;text-align:left' >Database name</TH>
                <TH style='font-weight:bold;text-align:right' >Type backup</TH>
                <TH style='font-weight:bold;text-align:center'>Start time</TH>
                <TH style='font-weight:bold;text-align:center' >End time</TH>
                <TH style='font-weight:bold;text-align:right' >Backup size</TH>
                </TR>"
    If ($data)
    {
    $line = ""
    ForEach ($row In $data)
    {
	If ($line -ne $row.server_name)
	{
		$iNumberDB = ($data | Where {$_.server_name -eq $row.server_name}).Count
#		$sHTML += "<tr style='background-color:#DBF0EB;font-weight:normal;font-family:Arial;color:#646464;font-size:1px'><td colspan=6>.</td></tr>"
		$sHTML += "<tr style='background-color:#DBF0EB;font-weight:bold;text-align:left'><td colspan=6>$($row.server_name) - backup database $iNumberDB</td></tr>"
#		$sHTML += "<tr style='background-color:#DBF0EB;font-weight:normal;font-family:Arial;color:#DBF0EB;font-size:1px'><td colspan=6>.</td></tr>"
	}
	$line = $row.server_name
	
        $sHTML += "<TR style='color:BLACK'>"
        $sHTML += "<TD style='font-weight:normal;text-align:left'>$($row.server_name)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:left'>$($row.database_name)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:right'>$($row.type)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:center'>$($row.backup_start_date)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:center'>$($row.backup_finish_date)</TD>"
        $sHTML += "<TD style='font-weight:normal;text-align:right'>$($row.backup_size)</TD>"
        $sHTML += "</TR>"
    }
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
        [Parameter(Mandatory=$True,Position=3)] [string]$Subject,
        [Parameter(Mandatory=$True,Position=4)] [string]$Body,
        [Parameter(Mandatory=$True,Position=5)] [string]$SMTPServer
    )

    $message = New-Object System.Net.Mail.MailMessage $from, $to
    $message.Subject = $subject
    $message.IsBodyHtml = $true
    $message.Body = $body
    
    $email = New-Object system.net.mail.smtpClient($SMTPserver)
    $email.Send($message)
}

$reportData = Get-BackupInfo -server $SQLServer -day $day
$sHTML = Get-HtmlReport -data $reportData -day $day
$sSubject = "[Info] Backup database : $($reportData.count)"
Send-Email -From $mailFrom -To $mailTo -Subject $sSubject -Body $sHTML -SMTPServer $SMTP