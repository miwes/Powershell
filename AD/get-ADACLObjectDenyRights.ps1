Import-Module ActiveDirectory

$schemaIDGUID = @{}

$ErrorActionPreference = 'SilentlyContinue'
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID | ForEach-Object {$schemaIDGUID.add([System.GUID]$_.schemaIDGUID,$_.name)}
Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID | ForEach-Object {$schemaIDGUID.add([System.GUID]$_.rightsGUID,$_.name)}

$ErrorActionPreference = 'Continue'

$AOs  = @(Get-ADDomain | Select-Object -ExpandProperty DistinguishedName)
$AOs += Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName
$AOs += Get-ADObject -SearchBase (Get-ADDomain).DistinguishedName -SearchScope Subtree -LDAPFilter '(objectClass=*)'

$denyObject = @()
ForEach ($AO in $AOs) {
    Write-Progress -Activity "Scan " -CurrentOperation "$($AO.DistinguishedName)" -PercentComplete (($i++/$AOs.Count) *100)
    
    Try {
        $DN = 'AD:\' + $AO.DistinguishedName + ''
        $testRights = Get-Acl -Path $DN -ErrorAction Stop

        If ($testRights) {
    
            $rights = $testRights | Select-Object -ExpandProperty Access | Select * | Where-Object {$_.AccessControlType -ne 'Allow'}
    
            If ($rights) {
                ForEach ($right in $rights) {
                    $denyRights = [PSCustomObject]@{
                        DN  = $AO
                        Type = $AO.objectClass
                        ActiveDirectoryRights = $right.ActiveDirectoryRights
                        IdentityReference = $right.IdentityReference
                        IsInherited = $right.IsInherited
                        AccessControlType = $right.AccessControlType
                        inheritedObjectTypeName = $schemaIDGUID.Item($right.objectType)
                        Error = ''

                    }
                    $denyObject += $denyRights
                }
            }
        } Else {
            $denyRights = [PSCustomObject]@{
                        DN  = $AO
                        Type = 'TOTAL NO READ'
                        ActiveDirectoryRights = 'TOTAL NO READ'
                        IdentityReference = ''
                        IsInherited = ''
                        AccessControlType = ''
                        inheritedObjectTypeName = ''
                        Error = ''
                    }
             $denyObject += $denyRights
        }
    } Catch {
        $denyRights = [PSCustomObject]@{
                    DN  = $AO
                    Type = $AO.objectClass
                    ActiveDirectoryRights = 'Error'
                    IdentityReference = ''
                    IsInherited = ''
                    AccessControlType = ''
                    inheritedObjectTypeName = ''
                    Error = $Error[0]

                }
        $denyObject += $denyRights
    }
} 

$denyObject | Out-GridView