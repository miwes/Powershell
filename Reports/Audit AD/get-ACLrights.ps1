Import-Module ActiveDirectory

# Načtení ACL pro AdminSDHolder
$AdminSDHolderDN = (Get-ADRootDSE).defaultNamingContext
$ACL = Get-Acl "AD:\CN=AdminSDHolder,CN=System,$AdminSDHolderDN"

# Zobrazení explicitně nastavených (nezděděných) práv
$ACL.Access | Where-Object { -not $_.IsInherited } | Select-Object IdentityReference, ActiveDirectoryRights, AccessControlType
