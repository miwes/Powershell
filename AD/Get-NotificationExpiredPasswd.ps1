<#
.SYNOPSIS
    Skript ne notifikaci expirujicich hesel
.DESCRIPTION
.NOTES
    Author : Michal Weis
.EXAMPLE
.PARAMETER WarningDay
    Pocet dni pred expiraci heslo urcenych pro notifikaci
.PARAMETER SMTPServer
    Jmeno SMTP serveru
.PARAMETER FromAddress
    Emailovat adresa
.PARAMETER DisplayNameFromAddress
    Zobrazeni pro emailovou adresu
.PARAMETER Subject
    Predmet emailu {0} - je promenna pocet dni
.PARAMETER Body
    Telo emailu v HTML formate.
.PARAMETER BodyParam
    Parametry tela emailu {0},{1}, ....
#>

[CmdletBinding()]Param (
    [Parameter(Mandatory=$False,Position=1)] [Alias("WarningDay")] [System.Array]$attrWarningDay = @(30,20)
    ,[Parameter(Mandatory=$False,Position=2)] [Alias("SMTPServer")] [String]$attrSMTP = 'ares.test.cz'
    ,[Parameter(Mandatory=$False,Position=3)] [Alias("FromAddress")] [String]$attrFromAddress = 'weis@logon.cz'
    ,[Parameter(Mandatory=$False,Position=4)] [Alias("DisplayNameFromAddress")] [String]$attrDisplayNameFromAddress = 'Upozorneni na expiraci hesla!'
    ,[Parameter(Mandatory=$False,Position=5)] [Alias("Subject")] [String]$attrSubject = 'Expirace hesla za {0} dni.'
    ,[Parameter(Mandatory=$False,Position=5)] [Alias("Body")] [String]$attrBody = "Vase heslo (uctu {0}) vyprsi dne {1}.<br><br>Nezapomente si ho zmenit.<br><br><B>IT</B>"
    ,[Parameter(Mandatory=$False,Position=5)] [Alias("BodyParam")] [String]$attrBodyParam = '$CN,$ExpiredDate'
    ,[Parameter(Mandatory=$False,Position=5)] [Alias("WhatIf")] [Switch]$attrWhatIf
)

Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
[threading.thread]::CurrentThread.CurrentCulture = 'cs-CZ' 

Function Send-Email () {

    [CmdletBinding()]Param (
        [Parameter(Mandatory=$False,Position=1)] [Alias("SMTPServer")] [String]$attrSMTP
        ,[Parameter(Mandatory=$False,Position=2)] [Alias("FromAddress")] [String]$attrFromAddress 
        ,[Parameter(Mandatory=$False,Position=3)] [Alias("DisplayNameFromAddress")] [String]$attrDisplayNameFromAddress
        ,[Parameter(Mandatory=$False,Position=4)] [Alias("ToAddress")] [String]$attrToAddress 
        ,[Parameter(Mandatory=$False,Position=5)] [Alias("Subject")] [String]$attrSubject
        ,[Parameter(Mandatory=$False,Position=6)] [Alias("Body")] [String]$attrBody
    )

    $message = New-Object System.Net.Mail.MailMessage 
    $message.From = New-Object System.Net.Mail.MailAddress $attrFromAddress,$attrDisplayNameFromAddress
    $message.To.Add($attrToAddress)
    $message.Subject = $attrSubject
    $message.IsBodyHtml = $true
    $message.Body = $attrBody
    
    $email = New-Object System.Net.Mail.SmtpClient($attrSMTP)
    Try {
        $email.Send($message)
    } Catch {
        Write-Warning "Error when send email: $($Error[0])"
    }
}


# search user from current AD
$oSearcher = New-Object System.DirectoryServices.DirectorySearcher
# all not disable user with no password never expire
$oSearcher.filter = "(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=65536)(!userAccountControl:1.2.840.113556.1.4.803:=2))"
[void]$oSearcher.PropertiesToLoad.Add("CN")
[void]$oSearcher.PropertiesToLoad.Add("mail")
[void]$oSearcher.PropertiesToLoad.Add("msDS-UserPasswordExpiryTimeComputed")
[void]$oSearcher.PropertiesToLoad.Add("distinguishedName")
$oUsers = $oSearcher.FindAll()

ForEach ($oUser In $oUsers) {
    # extract expired date
    [String]$iExpiredDate = $oUser.properties.item("msDS-UserPasswordExpiryTimeComputed")
    
    If ($iExpiredDate -eq '9223372036854775807') {
        Continue
    }
    # convert expired date to datetime
    $ExpiredDate = [datetime]::FromFileTime($iExpiredDate)

    # user must have email
    If ($oUser.properties.item("mail") -ne '') {
        # foreach WarningDay
        ForEach ($iDay In $attrWarningDay) {
            $ComputedExpiredDate = $ExpiredDate.AddDays(-$iDay).ToString("yyyMMdd")
            $Now = (Get-Date).ToString("yyyMMdd")

            # expired warning day
            If ($ComputedExpiredDate -eq $Now) {
                [string]$CN = $oUser.properties.item("CN")
                $subject = $attrSubject -f $iDay
                $Body = $attrBody -f (Invoke-Expression $attrBodyParam)
                
                
                If (-not $attrWhatIf) {
                    Write-Verbose "Notification user $($oUser.properties.item("mail")) - $CN"
                    Send-Email -attrSMTP $attrSMTP `
                                -attrFromAddress $attrFromAddress `
                                -attrDisplayNameFromAddress $attrDisplayNameFromAddress `
                                -attrToAddress $oUser.properties.item("mail") `
                                -attrSubject $subject `
                                -attrBody $body
                } Else {
                    Write-Host "User expired password $CN ($($oUser.properties.item("mail"))) after $iDay days - $ExpiredDate"
                }
            }
        }
    }
}
