<#
.SYNOPSIS
    Report Deny ACL rights in AD
.DESCRIPTION
    Version : 1.0.1
.NOTES
.LINK
.EXAMPLE
#>

<# TODO

#>

[CmdletBinding()]Param (
    [Parameter(Mandatory=$False)] [Alias("OU")] [string]$attrOU
)

# inicialization
Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
$Error.Clear()
Import-Module ActiveDirectory

$schemaIDGUID = @{}

$ErrorActionPreference = 'SilentlyContinue'
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID | ForEach-Object {$schemaIDGUID.add([System.GUID]$_.schemaIDGUID,$_.name)}
Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID | ForEach-Object {$schemaIDGUID.add([System.GUID]$_.rightsGUID,$_.name)}

$ErrorActionPreference = 'Continue'

If ($attrOU -eq '') {
    $AOs = @(Get-ADDomain | Select-Object -ExpandProperty DistinguishedName)
    $AOs += Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName
    $AOs += Get-ADObject -SearchBase (Get-ADDomain).DistinguishedName -SearchScope Subtree -LDAPFilter '(objectClass=*)'
} Else {
    $AOs = Get-ADObject -SearchBase $attrOU -SearchScope Subtree -LDAPFilter '(objectClass=*)'
}

$denyObjects = @()
$i = 0

ForEach ($AO in $AOs) {
    If ($AO.PSobject.Properties.name -match "DistinguishedName") {
        Write-Progress -Activity "Scan " -CurrentOperation "$($AO.DistinguishedName)" -PercentComplete (($i++/$AOs.Count) *100)
        Try {

            $DN = 'AD:\' + $AO.DistinguishedName + ''
            Write-Verbose "Check: $DN"
            $testRights = Get-Acl -Path $DN -ErrorAction Stop

            If ($testRights -is [System.Security.AccessControl.DirectoryObjectSecurity]) {

                $rights = $testRights | Select-Object -ExpandProperty Access | Select *
                If (-not $rights) {
                    
                    # divne objekt nema vubec zadna prava
                    $denyRightsObject = [PSCustomObject]@{
                            DN  = $AO
                            Type = 'TOTAL NO RIGHTS'
                            ActiveDirectoryRights = 'TOTAL NO RIGHTS'
                            IdentityReference = ''
                            IsInherited = ''
                            AccessControlType = ''
                            inheritedObjectTypeName = ''
                            Error = ''
                        }
                    $denyObjects += $denyRightsObject
                }

                $denyRights = $rights | Where-Object {$_.AccessControlType -ne 'Allow'}
        
                ForEach ($right in $denyRights) {
                    
                    # vypis vsechny DENY prava
                    $denyRightsObject = [PSCustomObject]@{
                        DN  = $AO
                        Type = $AO.objectClass
                        ActiveDirectoryRights = $right.ActiveDirectoryRights
                        IdentityReference = $right.IdentityReference
                        IsInherited = $right.IsInherited
                        AccessControlType = $right.AccessControlType
                        inheritedObjectTypeName = $schemaIDGUID.Item($right.objectType)
                        Error = ''

                    }
                    $denyObjects += $denyRightsObject
                }

            } Else {
                
                # vubec jsem nemohl nacist prava
                $denyRightsObject = [PSCustomObject]@{
                            DN  = $AO
                            Type = 'TOTAL NO READ'
                            ActiveDirectoryRights = 'TOTAL NO READ'
                            IdentityReference = ''
                            IsInherited = ''
                            AccessControlType = ''
                            inheritedObjectTypeName = ''
                            Error = ''
                        }
                 $denyObjects += $denyRightsObject
            }
        } Catch {

            # chyba pri nactinani ACL
            $denyRightsObject = [PSCustomObject]@{
                        DN  = $AO
                        Type = $AO.objectClass
                        ActiveDirectoryRights = 'Error'
                        IdentityReference = ''
                        IsInherited = ''
                        AccessControlType = ''
                        inheritedObjectTypeName = ''
                        Error = $Error[0]

                    }
            $denyObjects += $denyRightsObject
        }
    }
} 

$denyObjects | Out-GridView
