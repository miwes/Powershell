
Import-Module ActiveDirectory

Get-ADUser -Filter { ServicePrincipalName -like "*" } `
    -Properties ServicePrincipalName, Enabled, PasswordLastSet,
                PasswordNeverExpires, AdminCount, Description |
    Select-Object Name, SamAccountName, Enabled,
        PasswordLastSet, PasswordNeverExpires, AdminCount,
        ServicePrincipalName, Description |
    Sort-Object AdminCount, Name |
    Format-List
