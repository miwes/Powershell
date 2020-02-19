<#
.SYNOPSIS
    Clean WSUS server
.DESCRIPTION
    Reset client
    wuauclt.exe /resetauthorization /detectnow
.NOTES
    Author : Michal Weis
#>

[CmdletBinding()]Param (
)

$Updates = Get-WsusUpdate -Approval AnyExceptDeclined
$Updates | Where-Object {$_.update.title -like '*itanium*'} | Deny-WsusUpdate
Get-WsusServer | Invoke-WsusServerCleanup -CleanupObsoleteComputers -CleanupObsoleteUpdates -CleanupUnneededContentFiles -CompressUpdates -DeclineExpiredUpdates -DeclineSupersededUpdate