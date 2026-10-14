$domain = [ADSI]"LDAP://$(([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).GetDirectoryEntry().distinguishedName)"

# 1. Přesné GUIDy pro DCSync oprávnění v AD
$dcsyncGuids = @(
    "1131f6aa-9c07-11d1-f79f-00c04fc2dcd2", # DS-Replication-Get-Changes
    "1131f6ad-9c07-11d1-f79f-00c04fc2dcd2", # DS-Replication-Get-Changes-All
    "89e95b76-444d-4c62-991a-0facbeda640c"  # DS-Replication-Get-Changes-In-Filtered-Set
)

# 2. Kombinovaný filtr (GUIDy + Textový filtr nad ActiveDirectoryRights)
$domain.ObjectSecurity.Access | Where-Object {
    $guidStr = $_.ObjectType.ToString().ToLower()
    $rightsStr = $_.ActiveDirectoryRights.ToString()

    # Kontrola shody GUIDu
    $hasGuidMatch = $dcsyncGuids -contains $guidStr

    # Textový filtr nad oprávněními (např. plná práva nebo úprava ACL)
    $hasTextMatch = $rightsStr -match "GenericAll|WriteDacl|WRITE_DAC"

    return ($hasGuidMatch -or $hasTextMatch)
} | Select-Object IdentityReference, ActiveDirectoryRights, ObjectType, AccessControlType | Out-GrindView
