########################################################
# inactiveUsers.ps1 
#
# kontrola expirovanych hesel u uctu
# Michal Weis test(c) 2013

Import-Module ActiveDirectory
[threading.thread]::CurrentThread.CurrentCulture = 'en-US'

# pocet mesicu 
[int] $months = 2
$from = "ad@aclab.cz"
$to = "aaclab@test.cz"
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

Function New-User($SamAccountName,$lastLogon,$DistinguishedName, $whenCreated, $description)
{
   $user = New-Object PSObject | Select-Object Username, LastLogon, LDAPPath, whenCreated, Description
   $user.Username = $SamAccountName
   $user.LastLogon = $lastLogon
   $user.LDAPPath = $DistinguishedName 
   $user.whenCreated = $whenCreated
   $user.Description = $description

   Return $user
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
        @{Label="Uzivatel";Expression={$_.Username}},`
        @{Label="Datum vytvoreni uctu";Expression={$_.whenCreated}}, `
        @{Label="Datum posledniho prihlaseni";Expression={$_.LastLogon}}, `
        @{Label="Popis";Expression={$_.Description}}, `
        @{Label="LDAP cesta";Expression={$_.LDAPPath}}| `
        ConvertTo-Html -head $style 
    
    $date = Get-Date
    
    $HTMLHeader = "<h2><font face='Arial' color='black'>Seznam uzivatelu neaktivnich vice jak $months mesice.</font></h2>"
    $HTMLFooter = "<font face='Arial' size='2' color='gray'><br>
                   Cas spusteni: $date<br> `
                   Server: $env:COMPUTERNAME`
                   </font><br><br>" 

    Return $HTMLHeader + $HTMLBody + $HTMLFooter
}

Function MoveDisable-User($objUser, $targetOU)
{
    Try
    {
        #Set-ADUser -Identity $objUser -Enabled $false
        #Move-ADObject -Identity $objUser -TargetPath $targetOU
    }
    Catch
    {
        Return $false
    }
    Return $true
}

$objUsers = get-aduser -Filter {Enabled -eq $True} `
                        -SearchScope Subtree -SearchBase $LDAPCesta `
                        -Properties "samAccountName", "lastLogonTimestamp", "pwdLastSet", "distinguishedName", "whenCreated", "description"
$objResult = @()

ForEach ($user in $objUsers) 
{
   $lastLogon = [datetime]::FromFileTime($user."lastLogonTimestamp")
   
   If ($lastLogon -le ($(Get-Date).AddMonths(-$months)))
   {
        $lastLogon = [datetime]::FromFileTime($user."lastLogonTimestamp")
        $objResult += New-User $user.SamAccountName $lastLogon $user.DistinguishedName $user.whenCreated $user.description
   }
}

SendEmail $from $to "Automaticky skript na kontrolu neaktivnich uctu" (Create-HTMLBody($objResult)) $SMTPServer 