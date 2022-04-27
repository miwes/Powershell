########################################################
# inactiveComputers.ps1 
#
# kontrola expirovanych hesel u uctu
# Michal Weis test(c) 2013

Import-Module ActiveDirectory
[threading.thread]::CurrentThread.CurrentCulture = 'en-US'

# pocet mesicu 
[int] $months = 2
[string]$LDAPCesta = "DC=test,DC=local"


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

$objResult | Out-GridView