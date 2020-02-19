<#
.SYNOPSIS
    Skript na pridani uzivatelu v definovanem OU do definovane skupiny
.DESCRIPTION
.NOTES
Author : Michal Weis
#>

[CmdletBinding()]Param (
    [Parameter(Mandatory=$False,Position=1)] [Alias("OU")] [string]$attrOU = 'OU=Users,OU=LAB,DC=lab,DC=test'
    ,[Parameter(Mandatory=$False,Position=1)] [Alias("Group")] [string]$attrGroup = 'MMKompeteneceLidiEdit'
)

Try {
    Import-Module ActiveDirectory

    Write-Verbose "[Inf];Hledam uzivatele v OU $attrOU"
    $oUsers = Get-ADUser -SearchBase $attrOU -SearchScope OneLevel -Filter *
    Write-Verbose "[Inf];Nastavuji skupinu $attrGroup  pro uzivatele v OU $attrOU"
    Add-ADGroupMember -Identity $attrGroup -Members $oUsers
} Catch {
    Write-Verbose "[Error];$($Error[0])"
}