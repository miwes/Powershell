<#
    .SYNOPSIS
        Targetovaný bezpečnostní audit ACL pro objekt AdminSDHolder
#>

# Načtení domény a cesty k AdminSDHolderu
$domainDN = (Get-ADDomain).DistinguishedName
$adminSDHolderDN = "CN=AdminSDHolder,CN=System,$domainDN"

# Seznam oprávnění, která představují riziko (zápis, změna práv, vlastnictví, extended rights)
$dangerousRights = @(
    'GenericAll', 
    'WriteDacl', 
    'WriteOwner', 
    'GenericWrite', 
    'WriteProperty', 
    'Self', 
    'ExtendedRight'
)

# Standardní/očekávané účty a skupiny, které na AdminSDHolderu mají mít práva
$legitimateTrustees = @(
    'NT AUTHORITY\SYSTEM',
    'BUILTIN\Administrators',
    'Domain Admins',
    'Enterprise Admins',
    'NT AUTHORITY\SELF'
)

Write-Host "Kontroluji ACL na objektu: $adminSDHolderDN`n" -ForegroundColor Cyan

# Načtení ACL objektu AdminSDHolder
$acl = Get-Acl -Path "AD:\$adminSDHolderDN"

$findings = foreach ($access in $acl.Access) {
    
    # 1. Ignorujeme pouze čtecí/neškodná práva
    if ($access.AccessControlType -ne 'Allow') { continue }
    
    # 2. Kontrola nebezpečných práv
    $isDangerous = $false
    foreach ($right in $dangerousRights) {
        if ($access.ActiveDirectoryRights.ToString() -match $right) {
            $isDangerous = $true
            break
        }
    }
    if (-not $isDangerous) { continue }

    # 3. Kontrola, zda jde o nestandardní/nepovolený účet
    $trustee = $access.IdentityReference.Value
    
    # Rozlišení: Očekávané vs. Rizikové
    $status = if ($legitimateTrustees -contains $trustee) { "Očekávané (Standard)" } else { "CRITICAL / RIZIKOVÉ" }

    [PSCustomObject]@{
        Status          = $status
        Trustee         = $trustee
        Rights          = $access.ActiveDirectoryRights
        ObjectTypeGuid  = $access.ObjectType
        Inheritance     = $access.IsInherited
    }
}

# Vypíšeme pouze riziková / podezřelá zjištění
$criticals = $findings | Where-Object { $_.Status -eq "CRITICAL / RIZIKOVÉ" }

if ($criticals) {
    Write-Host "!!! POZOR: Na AdminSDHolderu byla nalomena neobvyklá nebo riziková oprávnění !!!" -ForegroundColor Red
    $criticals | Format-Table -AutoSize
} else {
    Write-Host "OK: Na AdminSDHolderu nebyly nalezeny žádné nestandardní účty s právy k zápisu/změně." -ForegroundColor Green
}

# Pokud chcete vidět i standardní správy pro kontrolu kompletnosti:
 $findings | Out-GridView -Title "Kompletní přehled práv na AdminSDHolder"
