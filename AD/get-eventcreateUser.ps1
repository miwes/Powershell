Set-Culture "en-US"
$securityLog = Get-WinEvent 'ForwardedEvents' -FilterXPath "*[System[(EventID=4720)]]" -MaxEvents 1;

$to = 'aaclab@test.cz';
$logArray = $securityLog.message.split("`n")

$createUser = $logArray[11].Split("`t")[3].Trim() + '\' + $logArray[10].Split("`t")[3].Trim()
$userName = $logArray[5].Split("`t")[3].Trim() + '\' + $logArray[4].Split("`t")[3].Trim()
$sourceEvent = $securityLog.machinename	

$subject = '[Create user] ' + $createUser + ' ' + $securityLog.TimeCreated 
    
    $sHTML = "<html><head><title>Delete user</title></head><body>"
    $sHTML += "<TABLE style='font-weight:normal; border-collapse: collapse'>"
    $SHTML += "<TR style='font-family:Arial;background-color:#A6DBCF'>
               <TH style='font-weight:bold;text-align:left' width='200'>Account delete</TH>
               <TH style='font-weight:bold;text-align:left' width='200'>Date/Time</TH>
               <TH style='font-weight:bold;text-align:left' width='200'>Source</TH>
               <TH style='font-weight:bold;text-align:left' width='200'>Who create</TH>
               </TR>"

$sHTML += "<TR style='color:BLACK;font-family:Arial'>"
$sHTML += "<TD style='font-weight:normal;text-align:left'>$($createUser)</TD>"
$sHTML += "<TD style='font-weight:normal;text-align:left'>$($securityLog.TimeCreated)</TD>"
$sHTML += "<TD style='font-weight:normal;text-align:left'>$($sourceEvent)</TD>"
$sHTML += "<TD style='font-weight:normal;text-align:left'>$($userName)</TD>"
$sHTML += "</TR>"
$sHTML += "</TABLE>"
$sHTML += "</body>"

Send-MailMessage -SmtpServer 'pasvex01.aclab.local' -From 'noretry@aclab.cz' -To $to -Body $sHTML -Subject $subject -BodyAsHtml
