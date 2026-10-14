# Vyhledá všechny účty s vypnutou Kerberos preautentizací
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $True} -Properties DoesNotRequirePreAuth, Enabled, PasswordLastSet, LastLogonDate | 
    Select-Object Name, SamAccountName, Enabled, PasswordLastSet, LastLogonDate | 
    Format-Table -AutoSize
