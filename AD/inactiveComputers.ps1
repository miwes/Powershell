########################################################
# inactiveComputers.ps1 
#
# kontrola expirovanych hesel u uctu
# Michal Weis Autocont(c) 2013

Import-Module ActiveDirectory
[threading.thread]::CurrentThread.CurrentCulture = 'en-US'

# pocet mesicu 
[int] $months = 2
$from = "ad@aclab.cz"
$to = "aaclab@autocont.cz"
$SMTPServer = "pasvex01"
$LDAPCesta = "DC=aclab,DC=local"

Function SendEmail ($from,$to,$subject,$body,$SMTPserver)
{
    $message = New-Object System.Net.Mail.MailMessage $from, $to
    $message.Subject = $subject
    $message.IsBodyHtml = $true
    $message.Body = $body
    
    $email = New-Object system.net.mail.smtpClient($SMTPserver)
    $email.Send($message)
}

Function New-Computer($name,$lastLogon,$DistinguishedName, $whenCreated, $description)
{
   $computer = New-Object PSObject | Select-Object Computer, LastLogon, LDAPPath, whenCreated, Description
   $computer.Computer = $Name
   $computer.LastLogon = $lastLogon
   $computer.LDAPPath = $DistinguishedName 
   $computer.whenCreated = $whenCreated
   $computer.Description = $description

   Return $computer
}

Function Create-HTMLBody($body)
{
    $style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
    $style = $style + "TABLE{border: 1px gray; border-collapse: collapse;}"
    $style = $style + "TH{border: 1px solid #A0A0A0; background: #dddddd; padding: 5px; }"
    $style = $style + "TD{border: 1px solid #A0A0A0; padding: 5px; }"
    $style = $style + "</style>"

    $HTMLBody = $objResult | `
    Sort-Object LastLogon | `
    Select-Object -Property `
        @{Label="Pocitac";Expression={$_.Computer}},`
        @{Label="Datum vytvoreni objektu";Expression={$_.whenCreated}}, `
        @{Label="Datum posledniho prihlaseni";Expression={$_.LastLogon}}, `
        @{Label="Popis";Expression={$_.Description}}, `
        @{Label="LDAP cesta";Expression={$_.LDAPPath}}| `
        ConvertTo-Html -head $style 
    
    $date = Get-Date
    
    $HTMLHeader = "<h2><font face='Arial' color='black'>Seznam pocitaci neaktivnich vice jak $months mesice.</font></h2>"
    $HTMLFooter = "<font face='Arial' size='2' color='gray'><br>
                   Cas spusteni: $date<br> `
                   Server: $env:COMPUTERNAME`
                   </font><br><br>" 

    Return $HTMLHeader + $HTMLBody + $HTMLFooter
}

$objComputers = Get-ADComputer -Filter {Enabled -eq $True} `
                                -SearchBase $LDAPCesta -SearchScope SubTree `
                                -Properties "Name", "lastLogonTimestamp","DistinguishedName", "whenCreated", "Description"
                                
$objResult = @()

ForEach ($computer in $objComputers) 
{
    $lastLogon = [datetime]::FromFileTime($computer."lastLogonTimestamp") 
    
   If ($lastLogon -le ($(Get-Date).AddMonths(-$months)))
   {
        $objResult += New-Computer $computer.Name $lastLogon $computer.DistinguishedName $computer.whenCreated $computer.description
   }
}

SendEmail $from $to "Automaticky skript na kontrolu neaktivnich pocitacu" (Create-HTMLBody($objResult)) $SMTPServer 