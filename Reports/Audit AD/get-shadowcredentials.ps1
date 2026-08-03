<#
.SYNOPSIS
    Detekuje UŽIVATELSKÉ účty v AD s atributem msDS-KeyCredentialLink (Shadow Credentials).
#>

Import-Module ActiveDirectory

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   KONTROLA SHADOW CREDENTIALS (POUZE UŽIVATELÉ)" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Filtrujeme přímo na úrovni LDAP dotazu: msDS-KeyCredentialLink existuje AND objectClass je user (a ne computer)
    $filter = 'msDS-KeyCredentialLink -like "*" -and objectClass -eq "user" -and objectClass -ne "computer"'
    
    $results = Get-ADObject -Filter $filter `
                            -Properties msDS-KeyCredentialLink, sAMAccountName, objectClass, whenChanged `
                            -ErrorAction Stop

    if ($results) {
        Write-Host "[!] NALEZENO $($results.Count) UŽIVATELSKÝCH OBJEKTŮ S NASTAVENÝM msDS-KeyCredentialLink!" -ForegroundColor Yellow
        Write-Host "    (Pokud v doméně nepoužíváte WHfB / FIDO2 pro UŽIVATELE, tyto účty prověřte)" -ForegroundColor DarkGray
        Write-Host ""

        $report = foreach ($obj in $results) {
            $rawKeys = $obj.'msDS-KeyCredentialLink'
            $keyCount = if ($rawKeys -is [array]) { $rawKeys.Count } else { 1 }

            [PSCustomObject]@{
                sAMAccountName    = $obj.sAMAccountName
                ObjectClass       = $obj.objectClass
                KeyCount          = $keyCount
                LastModified      = $obj.whenChanged
                DistinguishedName = $obj.DistinguishedName
            }
        }

        $report | Format-Table -Property sAMAccountName, ObjectClass, KeyCount, LastModified -AutoSize

        $csvPath = ".\ShadowCredentials_Users_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "[+] Výsledky vyexportovány do: $csvPath" -ForegroundColor Green

    } else {
        Write-Host "[OK] V doméně nebyly nalezeny žádné UŽIVATELSKÉ účty s msDS-KeyCredentialLink." -ForegroundColor Green
    }

} catch {
    Write-Host "[ERROR] Nepodařilo se provést dotaz do Active Directory: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
