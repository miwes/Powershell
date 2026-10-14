
#requires -Version 5.1
#requires -Modules GroupPolicy, ActiveDirectory

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory
Import-Module GroupPolicy

# ------------------------------------------------------------
# 1. Zjištění aktuální domény
# ------------------------------------------------------------

$Domain = Get-ADDomain
$DomainName = $Domain.DNSRoot

Write-Host ""
Write-Host "Doména: $DomainName" -ForegroundColor Cyan
Write-Host "Zjišťuji oprávnění k vytváření a úpravám GPO..." `
    -ForegroundColor Cyan

$Results = [System.Collections.Generic.List[object]]::new()

# ------------------------------------------------------------
# 2. Oprávnění ke každému existujícímu GPO
# ------------------------------------------------------------

$GPOs = Get-GPO -All -Domain $DomainName

foreach ($GPO in $GPOs) {
    try {
        $Permissions = Get-GPPermission `
            -Guid $GPO.Id `
            -DomainName $DomainName `
            -All `
            -ErrorAction Stop

        foreach ($Permission in $Permissions) {
            $Level = $Permission.Permission.ToString()

            $CanEdit = $Level -in @(
                "GpoEdit",
                "GpoEditDeleteModifySecurity"
            )

            $CanModifySecurity = $Level -eq "GpoEditDeleteModifySecurity"

            $CanRead = $Level -in @(
                "GpoRead",
                "GpoApply",
                "GpoEdit",
                "GpoEditDeleteModifySecurity"
            )

            # Vypisujeme oprávnění relevantní pro úpravu GPO.
            # Read a Apply samotné nejsou oprávnění k úpravám.
            if ($CanEdit -or $CanModifySecurity) {
                $Results.Add([PSCustomObject]@{
                    Typ                    = "Úprava existujícího GPO"
                    GPO                    = $GPO.DisplayName
                    GUID                   = $GPO.Id
                    UcetNeboSkupina        = $Permission.Trustee.Name
                    TypSubjektu            = $Permission.Trustee.SidType
                    Opravneni              = $Level
                    MuzeUpravovat           = $CanEdit
                    MuzeMenitOpravneni     = $CanModifySecurity
                    Dediceno                = $Permission.Inherited
                })
            }
        }
    }
    catch {
        Write-Warning "Nepodařilo se načíst oprávnění GPO '$($GPO.DisplayName)': $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# 3. Kdo může vytvářet GPO v doméně
# ------------------------------------------------------------
# Práva ke vytváření GPO se spravují na kontejneru
# CN=Policies,CN=System,<DN domény>.
# Zde načítáme jeho ACL a vypisujeme ACE s právy Create Child.

$PoliciesDN = "CN=Policies,CN=System,$($Domain.DistinguishedName)"
$LDAPPath = "LDAP://$PoliciesDN"

try {
    $Entry = New-Object System.DirectoryServices.DirectoryEntry($LDAPPath)
    $null = $Entry.NativeObject
    $ACL = $Entry.ObjectSecurity

    $Rules = $ACL.GetAccessRules(
        $true,
        $true,
        [System.Security.Principal.SecurityIdentifier]
    )

    foreach ($Rule in $Rules) {
        if (
            $Rule.AccessControlType -eq
                [System.Security.AccessControl.AccessControlType]::Allow -and
            (
                $Rule.ActiveDirectoryRights -band
                [System.DirectoryServices.ActiveDirectoryRights]::CreateChild
            )
        ) {
            $Identity = $Rule.IdentityReference.Value

            try {
                $Identity = $Rule.IdentityReference.Translate(
                    [System.Security.Principal.NTAccount]
                ).Value
            }
            catch {}

            $Results.Add([PSCustomObject]@{
                Typ                    = "Možnost vytvářet GPO – ACL kontejneru"
                GPO                    = "(všechna GPO v doméně)"
                GUID                   = ""
                UcetNeboSkupina        = $Identity
                TypSubjektu            = ""
                Opravneni              = $Rule.ActiveDirectoryRights.ToString()
                MuzeUpravovat           = $false
                MuzeMenitOpravneni     = $false
                Dediceno                = $Rule.IsInherited
            })
        }
    }

    $Entry.Dispose()
}
catch {
    Write-Warning "Nepodařilo se načíst ACL kontejneru Policies: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# 4. Výstup
# ------------------------------------------------------------

Write-Host ""
Write-Host "Počet nalezených položek: $($Results.Count)" `
    -ForegroundColor Yellow

if ($Results.Count -gt 0) {
    $Output = $Results | Sort-Object Typ, GPO, UcetNeboSkupina

    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
        $Output | Out-GridView -Title "Audit oprávnění GPO – $DomainName"
    }
    else {
        $Output | Format-Table -AutoSize -Wrap
    }
}
else {
    Write-Host "Nebyly nalezeny žádné odpovídající položky." `
        -ForegroundColor Green
}
