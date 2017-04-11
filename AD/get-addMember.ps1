#
# version 1.1
# 13.12.2016 - add SID translate for add user
#

Set-Culture "en-US"
# EventID 4728 - Global Group
# EventID 4756 - Universal Group
# EventID 4732 - LocalGroup

Function Translate-SID
{
	Param
	(
        	[Parameter(Mandatory = $true,valueFromPipeline=$true)] [string]$SID
	)
	
	$objSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
	Return	$objSID.Translate( [System.Security.Principal.NTAccount]).Value
}

$securityLog = Get-WinEvent 'ForwardedEvents' -FilterXPath "*[System[(EventID=4728 or EventID=4756 or EventID=4732)]]" -MaxEvents 1;

$to = 'aaclab@autocont.cz';
$logArray = $securityLog.message.split("`n")

$ADGroup = $logArray[14].Split("`t")[3].Trim()

If ($ADGroup -like '*admin*')
{
	$user = $logArray[5].Split("`t")[3].Trim() + '\' + $logArray[4].Split("`t")[3].Trim()
	$addSID = $logArray[9].Split("`t")[3].Trim()
	$addUserSID = Translate-SID -SID $addSID

	$addUser =  $logArray[10].Split("`t")[3].Trim()
	$sourceEvent = $securityLog.machinename	

	$subject = '[Add member to group ' + $ADGroup + ']' + $securityLog.TimeCreated 

	$sHTML = "<html><head><title>Add member to group $ADGROUP</title></head><body>"
    	$sHTML += "<TABLE style='font-weight:normal; border-collapse: collapse'>"
    	$SHTML += "<TR style='font-family:Arial;background-color:#A6DBCF'>
               <TH style='font-weight:bold;text-align:left' width='600'>Account</TH>
               <TH style='font-weight:bold;text-align:left' width='200'>Group</TH>
               <TH style='font-weight:bold;text-align:left' width='200'>Date/Time</TH>
               <TH style='font-weight:bold;text-align:left' width='200'>Source</TH>
               <TH style='font-weight:bold;text-align:left' width='200'>Who added</TH>
               </TR>"

	$sHTML += "<TR style='color:BLACK;font-family:Arial'>"
	$sHTML += "<TD style='font-weight:normal;text-align:left'>$($addUser) / $($addUserSID)</TD>"
	$sHTML += "<TD style='font-weight:normal;text-align:left'>$($adgroup)</TD>"
	$sHTML += "<TD style='font-weight:normal;text-align:left'>$($securityLog.TimeCreated)</TD>"
	$sHTML += "<TD style='font-weight:normal;text-align:left'>$($sourceEvent)</TD>"
	$sHTML += "<TD style='font-weight:normal;text-align:left'>$($user)</TD>"
	$sHTML += "</TR>"
	$sHTML += "</TABLE>"
	$sHTML += "</body>"

	Send-MailMessage -SmtpServer 'pasvex01.aclab.local' -From 'noretry@aclab.cz' -To $to -Body $sHTML -Subject $subject -BodyAsHtml
}
