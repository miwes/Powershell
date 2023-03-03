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
     [Parameter(Mandatory=$False)] [string]$PathVHD = 'D:\Shares\UserProfiles\Farma40'
    ,[Parameter(Mandatory=$False)][string]$AuditLog = "c:\ac\LOG\$(Get-Date -Format('yyyy-MM-dd'))_AuditLog.txt"
)

$VHDxFiles = get-childitem -path $PathVHD -Recurse -Include *.vhdx

ForEach ($VHDx In $VHDxFiles) {

   $oldSID = $VHDx.Name.Split('.')[0].Replace('UVHD-','')

   $User = Get-ADUser -Filter * -Properties sidhistory | Where-Object {$_.sidhistory -eq $oldSID}
    
   [string]$Date = $(Get-Date -Format('yyyy-MM-dd HH:mm:ss'))      

   If ($User) {
        Try {
            
            $NewSID = $($User.SID).Value
            Write-Verbose "Rename $($VHDx.FullName) -> UVHD-$($NewSID).vhdx"
            "[$Date];$($User.Name);[Inf]; Rename $($VHDx.FullName) -> UVHD-$($NewSID).vhdx" | Out-file $AuditLog -Append
            $OldName = $VHDx.Name
            Rename-Item -Path $VHDx.FullName -NewName "UVHD-$NewSID.vhdx" -ErrorAction Stop
            $ACL = Get-ACL "$PathVHD"

            # pokud nenajde uzivatele neni nastavene pravo !!!! 
            $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("FLS\$($User.SamAccountName)","FullControl","Allow")
            $Acl.SetAccessRule($Ar)
            $ACL.SetAccessRuleProtection($False,$True)
        
            Set-ACL "$PathVHD\UVHD-$NewSID.vhdx" $ACL
            
        } Catch {
            "[$Date];$($User.Name);[Inf]; Rollback rename UVHD-$($NewSID).vhdx -> $($VHDx.FullName)" | Out-file $AuditLog -Append
            Rename-Item -Path $PathVHD\"UVHD-$NewSID.vhdx" -NewName $OldName
            Write-Host "[Error] - $($User.Name) VHDx Error - $($Error[0])" -BackgroundColor red
            "[$Date];$($User.Name);[Error]; VHDx Error $VHDx.FullName;  $($Error[0])" | Out-File $AuditLog -Append
        }

   }
}