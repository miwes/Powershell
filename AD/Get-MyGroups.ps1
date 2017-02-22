[cmdletbinding()]
Param(
    [string] $GroupName = 'Domain Users'
)

Function Get-MyGroups () {
    Param ()
    $objGroups = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups
    ForEach($group In $objGroups) {
        $GroupName = New-Object System.Security.Principal.SecurityIdentifier($Group.Value)
        $GroupDisplayName = $GroupName.Translate([System.Security.Principal.NTAccount])
        $GroupDisplayName
    }
}

Write-Verbose 'Zjistuji me skupiny ...'
If (Get-MyGroups | Where-Object {$_.Value -like "*$GroupName*"}) {
    Write-Host 'Jsem'
}
