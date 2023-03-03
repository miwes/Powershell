<#
.SYNOPSIS
.DESCRIPTION
.NOTES
Author : Michal Weis
.LINK
.EXAMPLE
.PARAMETER foo
.PARAMETER bar
#>

[CmdletBinding()]Param (
     [Parameter(Mandatory=$False)] [string]$PathVHD = 'D:\Shares\UserProfiles\Farma20'
    ,[Parameter(Mandatory=$False)][string]$AuditLog = "c:\ac\LOG\$(Get-Date -Format('yyyy-MM-dd'))_AuditLog_SetRight.txt"
)

$VHDxFiles = Get-ChildItem -path $PathVHD -Recurse -Include *.vhdx

ForEach ($VHDx In $VHDxFiles) {

   $SID = $VHDx.Name.Split('.')[0].Replace('UVHD-','')

   $User = Get-ADUser -Filter * -Properties Sid | Where-Object {$_.sid -eq $SID}
   If (!($User)) {
    $User = Get-ADUser -Filter * -Properties sidhistory | Where-Object {$_.sidhistory -eq $SID} 
   }

   [string]$Date = $(Get-Date -Format('yyyy-MM-dd HH:mm:ss'))      

   If ($User) {
        Try {
            
            $ACL = Get-ACL "$PathVHD"

            $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("FLS\$($User.SamAccountName)","FullControl","Allow")
            $ACL.SetAccessRule($Ar)
            $ACL.SetAccessRuleProtection($False,$True)
        
            Write-Verbose "[Inf] - $($User.Name) set right for $($VHDX.name)" 
            "[$Date];$($User.Name);[Inf];$($User.Name) set right for $($VHDX.name);  $($Error[0])" | Out-File $AuditLog -Append
            Set-ACL $VHDx.FullName $ACL
            
        } Catch {
            Write-Host "[Error] - $($User.Name) VHDx Error - $($Error[0])" -BackgroundColor red
            "[$Date];$($User.Name);[Error]; VHDx Error $VHDx.FullName;  $($Error[0])" | Out-File $AuditLog -Append
        }

   } Else {
     Write-Host "[Error] - Cannot find user for $SID" -BackgroundColor red
     "[$Date];$($User.Name);[Error];Cannot find user for $SID" | Out-File $AuditLog -Append
   }
}