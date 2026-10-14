
# ============================================================
# Filtr standardních systémových účtů a skupin
# ============================================================

$StandardNames = @(
    "Everyone",
    "NT AUTHORITY\Authenticated Users",
    "NT AUTHORITY\SYSTEM",
    "NT AUTHORITY\LOCAL SERVICE",
    "NT AUTHORITY\NETWORK SERVICE",
    "BUILTIN\Administrators",
    "BUILTIN\Users",
    "BUILTIN\Account Operators",
    "BUILTIN\Server Operators",
    "BUILTIN\Print Operators",
    "BUILTIN\Backup Operators",
    "BUILTIN\Pre-Windows 2000 Compatible Access",
    "NT AUTHORITY\ENTERPRISE DOMAIN CONTROLLERS",
    "CREATOR OWNER",
    "NT AUTHORITY\SELF"
)

# Standardní vestavěné skupiny domény (RID)
$StandardDomainRIDs = @(
    512, # Domain Admins
    513, # Domain Users
    514, # Domain Guests
    515, # Domain Computers
    516, # Domain Controllers
    517, # Cert Publishers
    518, # Schema Admins
    519, # Enterprise Admins
    520, # Group Policy Creator Owners
    521, # Read-only Domain Controllers
    522, # Cloneable Domain Controllers
    525, # Protected Users
    526, # Key Admins
    527  # Enterprise Key Admins
)

$DomainSID = (Get-ADDomain).DomainSID.Value

$FilteredResults = @(
    $Results | Where-Object {
        $Name = $_.UcetNeboSkupina
        $SID = $_.SID

        # Ponechat nestandardní a vlastní identity
        $IsStandard = $Name -in $StandardNames

        # Vestavěné skupiny domény identifikované pomocí SID
        if ($SID -match '^S-1-5-21-(\d+-){3}(\d+)$') {
            $RID = [int]($SID -split '-')[-1]

            if (
                $SID.StartsWith("$DomainSID-") -and
                $RID -in $StandardDomainRIDs
            ) {
                $IsStandard = $true
            }
        }

        # Odstranit pouze standardní identity
        -not $IsStandard
    }
)

# Následující slučovací část musí pracovat s filtrem:
$MergedResults = @(
    $FilteredResults |
        Group-Object Typ, GPO, GUID, UcetNeboSkupina, SID, AccessControlType |
        ForEach-Object {
            $Items = @($_.Group)

            $AllRelevantRights = @(
                $Items |
                    ForEach-Object { $_.RelevantniPrava -split ",\s*" } |
                    Where-Object { $_ } |
                    Sort-Object -Unique
            )

            $AllADRights = @(
                $Items |
                    ForEach-Object { $_.Opravneni -split ",\s*" } |
                    Where-Object { $_ } |
                    Sort-Object -Unique
            )

            $First = $Items[0]

            [PSCustomObject]@{
                Typ                 = $First.Typ
                GPO                 = $First.GPO
                GUID                = $First.GUID
                UcetNeboSkupina     = $First.UcetNeboSkupina
                SID                 = $First.SID
                AccessControlType   = $First.AccessControlType
                Opravneni           = $AllADRights -join ", "
                RelevantniPrava     = $AllRelevantRights -join ", "
                ObjectType          = (
                    $Items | ForEach-Object { $_.ObjectType } |
                    Sort-Object -Unique
                ) -join ", "
                InheritedObjectType = (
                    $Items | ForEach-Object { $_.InheritedObjectType } |
                    Sort-Object -Unique
                ) -join ", "
                InheritanceType     = (
                    $Items | ForEach-Object { $_.InheritanceType } |
                    Sort-Object -Unique
                ) -join ", "
                IsInherited         = (
                    $Items | ForEach-Object { $_.IsInherited } |
                    Sort-Object -Unique
                ) -join ", "
            }
        }
)
