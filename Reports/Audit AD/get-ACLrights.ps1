
#requires -Version 5.1
#requires -Modules ActiveDirectory

[CmdletBinding()]
param(
    [string]$Server = "",

    # Standardne zobrazit jen odchylky od zakladniho profilu.
    [switch]$ShowAll = $true
)

$ErrorActionPreference = "Stop"

function Resolve-PrincipalName {
    param($Identity)

    try {
        return $Identity.Translate(
            [System.Security.Principal.NTAccount]
        ).Value
    }
    catch {
        return $Identity.Value
    }
}

function Get-RiskAssessment {
    param(
        [string]$SID,
        [string]$Rights,
        [string]$AccessType,
        [string]$ObjectTypeGUID,
        [string]$InheritedObjectTypeGUID,
        [bool]$IsInherited,
        [string]$DomainSID,
        [string]$ForestRootSID
    )

    $rightList = @(
        $Rights -split ",\s*" |
        ForEach-Object { $_.Trim() }
    )

    $isAllow = $AccessType -eq "Allow"

    $broadSIDs = @(
        "S-1-1-0",       # Everyone
        "S-1-5-7",       # Anonymous
        "S-1-5-11",      # Authenticated Users
        "S-1-5-32-554",  # Pre-Windows 2000 Compatible Access
        "$DomainSID-513" # Domain Users
    )

    $isBroad = $SID -in $broadSIDs

    $isDA = $SID -eq "$DomainSID-512"
    $isEA = $SID -eq "$ForestRootSID-519"
    $isBuiltinAdmins = $SID -eq "S-1-5-32-544"
    $isSystem = $SID -eq "S-1-5-18"
    $isSelf = $SID -eq "S-1-5-10"

    $hasGenericAll = "GenericAll" -in $rightList
    $hasGenericWrite = "GenericWrite" -in $rightList
    $hasWriteDacl = "WriteDacl" -in $rightList
    $hasWriteOwner = "WriteOwner" -in $rightList
    $hasWriteProperty = "WriteProperty" -in $rightList
    $hasCreateChild = "CreateChild" -in $rightList
    $hasDeleteChild = "DeleteChild" -in $rightList
    $hasDeleteTree = "DeleteTree" -in $rightList
    $hasDelete = "Delete" -in $rightList
    $hasExtendedRight = "ExtendedRight" -in $rightList
    $hasSelfRight = "Self" -in $rightList

    $hasHighRisk = (
        $hasGenericAll -or
        $hasGenericWrite -or
        $hasWriteDacl -or
        $hasWriteOwner
    )

    # Ocekavana siroka administrativni prava.
    # Neignorujeme ale neobvykle kombinace jen podle nazvu uctu.
    $isExpectedAdmin = (
        $isDA -or $isEA -or $isBuiltinAdmins -or $isSystem
    )

    if ($isAllow -and $isExpectedAdmin -and $hasHighRisk) {
        return [PSCustomObject]@{
            IsBaseline = $true
            Severity   = "STANDARD"
            Category   = "Ocekavana administrativni prava"
            Reason     = "Známý privilegovaný principal s očekávaným širokým oprávněním. Ověřte odchylky od referenční ACL."
        }
    }

    if ($AccessType -eq "Deny") {
        return [PSCustomObject]@{
            IsBaseline = $false
            Severity   = "KONTROLA"
            Category   = "Deny ACE"
            Reason     = "Zakazove pravidlo není automaticky chybné, ale vyžaduje ověření rozsahu a důvodu."
        }
    }

    # Siroke identity s pravem menit zabezpeceni nebo zapisovat.
    if ($hasHighRisk -and $isBroad) {
        return [PSCustomObject]@{
            IsBaseline = $false
            Severity   = "KRITICKE"
            Category   = "Siroka identita"
            Reason     = "Siroka identita ma povoleno pravo uplne kontroly, zmeny DACL, vlastnika nebo obecneho zapisu."
        }
    }

    if ($hasHighRisk) {
        return [PSCustomObject]@{
            IsBaseline = $false
            Severity   = "VYSOKE"
            Category   = "Zmena zabezpeceni"
            Reason     = "Povolene pravo muze umoznit zmenu ACL, vlastnika nebo objektu. Overte opravnenost identity."
        }
    }

    # Bezna vychozi prava pro cteni.
    $readOnlyRights = @(
        "ReadProperty",
        "ReadControl",
        "ListChildren",
        "ListObject"
    )

    $isReadOnly = @(
        $rightList | Where-Object {
            $_ -notin $readOnlyRights
        }
    ).Count -eq 0

    if ($isAllow -and $isReadOnly -and $isBroad) {
        return [PSCustomObject]@{
            IsBaseline = $true
            Severity   = "STANDARD"
            Category   = "Standardni cteni"
            Reason     = "Pouze prava cteni pro sirokou identitu."
        }
    }

    # Standardni prava zmeny vlastniho hesla.
    $changePasswordGUID = "00299570-246d-11d0-a768-00aa006e0529"

    if (
        $isAllow -and
        ($SID -eq "S-1-1-0" -or $isSelf) -and
        $hasExtendedRight -and
        $ObjectTypeGUID -eq $changePasswordGUID -and
        $rightList.Count -eq 1
    ) {
        return [PSCustomObject]@{
            IsBaseline = $true
            Severity   = "STANDARD"
            Category   = "Zmena hesla"
            Reason     = "Standardni extended right pro zmenu hesla."
        }
    }

    # SYSTEM ma standardne plnou kontrolu.
    if ($isAllow -and $isSystem -and $hasGenericAll) {
        return [PSCustomObject]@{
            IsBaseline = $true
            Severity   = "STANDARD"
            Category   = "SYSTEM"
            Reason     = "Standardni plna kontrola SYSTEM."
        }
    }

    # Dalsi prava se nesmeji bez znalosti GUID automaticky povazovat za bezpecna.
    $hasOtherWrite = (
        $hasWriteProperty -or
        $hasCreateChild -or
        $hasDeleteChild -or
        $hasDeleteTree -or
        $hasDelete -or
        $hasExtendedRight -or
        $hasSelfRight
    )

    if ($hasOtherWrite) {
        return [PSCustomObject]@{
            IsBaseline = $false
            Severity   = "KONTROLA"
            Category   = "Specialni nebo zapisovaci pravo"
            Reason     = "Pravo nebylo rozpoznano jako bezpecna standardni kombinace. Overte ObjectType GUID a identitu."
        }
    }

    if ($IsInherited) {
        return [PSCustomObject]@{
            IsBaseline = $false
            Severity   = "KONTROLA"
            Category   = "Zdedene pravidlo"
            Reason     = "AdminSDHolder ma mit standardne chranenou ded icnost. Overte, proc je toto pravidlo zdedene."
        }
    }

    return [PSCustomObject]@{
        IsBaseline = $false
        Severity   = "KONTROLA"
        Category   = "Neoverena ACE"
        Reason     = "Pravidlo nebylo porovnano s uplnou referencni ACE. Overte ho rucne."
    }
}

# ============================================================
# NAC TENI DOMENY A FORESTU
# ============================================================

$entry = $null

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($Server)) {
        $domain = Get-ADDomain -ErrorAction Stop
        $forest = Get-ADForest -ErrorAction Stop
    }
    else {
        $domain = Get-ADDomain -Server $Server -ErrorAction Stop
        $forest = Get-ADForest -Server $Server -ErrorAction Stop
    }

    $domainDN = $domain.DistinguishedName
    $domainSID = $domain.DomainSID.Value
    $forestRootSID = (Get-ADDomain -Identity $forest.RootDomain).DomainSID.Value

    $adminSDHolderDN = "CN=AdminSDHolder,CN=System,$domainDN"

    if ([string]::IsNullOrWhiteSpace($Server)) {
        $ldapPath = "LDAP://$adminSDHolderDN"
    }
    else {
        $ldapPath = "LDAP://$Server/$adminSDHolderDN"
    }

    $entry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
    $null = $entry.NativeObject

    $acl = $entry.ObjectSecurity

    if ($null -eq $acl) {
        throw "ACL objektu AdminSDHolder je prazdne."
    }

    $rules = $acl.GetAccessRules(
        $true,
        $true,
        [System.Security.Principal.SecurityIdentifier]
    )

    $owner = $acl.GetOwner(
        [System.Security.Principal.SecurityIdentifier]
    ).Value

    $inheritanceProtected = $acl.AreAccessRulesProtected
}
catch {
    if ($entry) {
        $entry.Dispose()
    }

    Write-Host "CHYBA: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

# ============================================================
# VYHODNOCENI ACL
# ============================================================

$results = [System.Collections.Generic.List[object]]::new()
$index = 0

foreach ($ace in $rules) {
    $index++

    $sid = $ace.IdentityReference.Value
    $principal = Resolve-PrincipalName $ace.IdentityReference
    $rights = $ace.ActiveDirectoryRights.ToString()
    $accessType = $ace.AccessControlType.ToString()

    $assessment = Get-RiskAssessment `
        -SID $sid `
        -Rights $rights `
        -AccessType $accessType `
        -ObjectTypeGUID $ace.ObjectType.ToString() `
        -InheritedObjectTypeGUID $ace.InheritedObjectType.ToString() `
        -IsInherited ([bool]$ace.IsInherited) `
        -DomainSID $domainSID `
        -ForestRootSID $forestRootSID

    $results.Add([PSCustomObject]@{
        ID                      = $index
        Severity                = $assessment.Severity
        IsBaseline              = $assessment.IsBaseline
        Category                = $assessment.Category
        Principal               = $principal
        SID                     = $sid
        AccessType              = $accessType
        Rights                  = $rights
        IsInherited             = [bool]$ace.IsInherited
        InheritanceType         = $ace.InheritanceType.ToString()
        ObjectTypeGUID          = $ace.ObjectType.ToString()
        InheritedObjectTypeGUID = $ace.InheritedObjectType.ToString()
        Reason                  = $assessment.Reason
    })
}

if ($entry) {
    $entry.Dispose()
}

# ============================================================
# VYBER ODCHYLEK
# ============================================================

$deviations = @(
    $results | Where-Object { -not $_.IsBaseline }
)

Write-Host ""
Write-Host "ADMINSDHOLDER - ACL AUDIT" -ForegroundColor Cyan
Write-Host "Domena: $($domain.DNSRoot)"
Write-Host "Objekt: $adminSDHolderDN"
Write-Host "Vlastnik SID: $owner"
Write-Host "Dedicnost ACL chranena: $inheritanceProtected"
Write-Host "Celkem ACE: $($results.Count)"
Write-Host "Rozpoznane standardni ACE: $(@($results | Where-Object IsBaseline).Count)"
Write-Host "Odchylky / pravidla ke kontrole: $($deviations.Count)"
Write-Host ""

foreach ($severity in @("KRITICKE", "VYSOKE", "KONTROLA")) {
    $count = @(
        $deviations | Where-Object Severity -eq $severity
    ).Count

    $color = switch ($severity) {
        "KRITICKE" { "Red" }
        "VYSOKE"   { "DarkRed" }
        default    { "Yellow" }
    }

    Write-Host ("{0,-12} {1,4}" -f $severity, $count) -ForegroundColor $color
}

# ============================================================
# GRIDVIEW
# ============================================================

if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
    if ($ShowAll) {
        $gridData = $results
        $title = "AdminSDHolder - vsechny ACE"
    }
    else {
        $gridData = $deviations
        $title = "AdminSDHolder - odchylky a pravidla ke kontrole"
    }

    $gridData |
        Select-Object ID, Severity, Category, Principal, SID,
            AccessType, Rights, IsInherited, ObjectTypeGUID,
            InheritedObjectTypeGUID, Reason |
        Out-GridView -Title $title
}
else {
    Write-Host ""
    Write-Host "Out-GridView neni dostupny; vypisuji odchylky." -ForegroundColor Yellow

    $deviations |
        Format-Table Severity, Principal, AccessType, Rights, Reason -Wrap -AutoSize
}

Write-Host ""
Write-Host "Audit dokoncen. Nebyly vytvoreny soubory ani zmenena AD ACL." -ForegroundColor Green
Write-Host "Pro zobrazeni vsech ACE spustte: .\Audit-AdminSDHolder.ps1 -ShowAll"
