$domain = [ADSI]"LDAP://DC=domain,DC=local"

$domain.ObjectSecurity.Access | Where-Object {
    $rights = $_.ActiveDirectoryRights.ToString()
    $guid = $_.ObjectType.ToString()
    
    # Hledáme buď konkrétní GUID replikace, nebo plná práva GenericAll / WriteDacl
    ($guid -eq "1131f6aa-9c0e-11d1-a7f3-00c04fb9603f") -or 
    ($guid -eq "1131f6ad-9c0e-11d1-a7f3-00c04fb9603f") -or 
    ($rights -match "GenericAll|WriteDacl|WRITE_DAC")
} | Format-Table IdentityReference, ActiveDirectoryRights, AccessControlType -AutoSize
