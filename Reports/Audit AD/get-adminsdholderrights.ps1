  # Import modulu Active Directory (pokud již není načten)
Import-Module ActiveDirectory

try {
    # 1. Získání Distinguished Name (DN) aktuální domény a objektu AdminSDHolder
    $domainDN = (Get-ADDomain).DistinguishedName
    $adminSDHolderDN = "CN=AdminSDHolder,CN=System,$domainDN"
    
    Write-Host "Načítám oprávnění pro: $adminSDHolderDN" -ForegroundColor Cyan

    # 2. Načtení ACL (Access Control List) z Active Directory
    $acl = Get-Acl -Path "AD:\$adminSDHolderDN"

    # 3. Formátovaný výstup do konzole
    $permissions = $acl.Access | Select-Object @(
        @{Name='Uživatel/Skupina'; Expression={$_.IdentityReference}},
        @{Name='Typ přístupu';      Expression={$_.AccessControlType}},
        @{Name='Oprávnění';        Expression={$_.ActiveDirectoryRights}},
        @{Name='Zděděno';           Expression={$_.IsInherited}},
        @{Name='Typ objektu';       Expression={$_.ObjectType}}
    )

    # Výpis do konzole
    $permissions | Format-Table -AutoSize

    # VOLITELNĚ: Zobrazení v interaktivním okně (odkomentujte řádek níže pro filtrování)
    # $permissions | Out-GridView -Title "Oprávnění na AdminSDHolder ($adminSDHolderDN)"

}
catch {
    Write-Error "Chyba při načítání oprávnění: $_"
}
