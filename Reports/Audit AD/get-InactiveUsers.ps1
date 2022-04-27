########################################################
# inactiveUsers.ps1 
#
# kontrola expirovanych hesel u uctu
# Michal Weis test(c) 2013

Import-Module ActiveDirectory
[threading.thread]::CurrentThread.CurrentCulture = 'en-US'

# pocet mesicu 
[int] $months = 2
$LDAPCesta = "DC=test,DC=local"


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

$objResult | out-GridView