<#
.SYNOPSIS
    AD audit
    Version : 	1.0 - Init release
    		1.1 - Add more security groups
		1.2 - Add AdminSDHolder
.DESCRIPTION
.NOTES
.LINK
.EXAMPLE
.PARAMETER foo
.PARAMETER bar
#>

<# TODO

#>

[CmdletBinding()]Param (
    [Parameter(Mandatory=$False)] [Alias("ConfigFile")] [string]$attr
)

#region function
Function Get-ADGroupMembers {

	param(
		[string]$GroupName
        ,[string]$Level
	)
	
	$objects = @()
    Try {
	    $members = Get-ADGroupMember -Identity $GroupName 
    } Catch {
        Continue
    }

    $Level += $GroupName + " -> "
	ForEach ($member in $members) {

        If ($member.objectClass -eq 'group') {
            
            Try {
    	        $objects += Get-AdGroupMembers -GroupName $member.Name -Level $Level
            } Catch {
                Continue
            }
        } Else {
            
            Try {
                $User = Get-ADObject $member -Properties enabled		
                
                $enabled = ''
                If ( $User.objectclass -eq "user") {
                    $enabled = (Get-AdUser $member ).enabled
                } ElseIf ( $User.objectclass -eq "computer") {
                    $enabled = (Get-ADComputer $member ).enabled
                } 

                $lastLogon = ''
                If ( $User.objectclass -eq "user") {
                    $lastLogon = (Get-AdUser $member -properties lastlogondate).lastlogondate
                } ElseIf ( $User.objectclass -eq "computer") {
                    $lastLogon = (Get-ADComputer $member -properties lastlogondate).lastlogondate
                } 

            } Catch {
                Continue
            }

            $LevelTree = $Level.Substring(0,$Level.Length -3)	
		    $objects += @{
                "level"  = $LevelTree;
			    "type"   = $member.objectClass;
			    "name"   = $member.Name;
			    "group"  = $GroupName
                "status" = $enabled
                "lastLogon" = $lastLogon
                "distinguishedName" = $member.distinguishedName

            }
		  
        }
    		
	} 
	
	return $objects
	
} 

Function Get-ReportADGroup {
    # find PrivilegedGroupAccounts
    $ADGroup = @('Administrators','Domain Admins','Enterprise Admins','Schema Admins','Protected Users','Account Operators','Allowed RODC Password Replication Group','Backup Operators','Certificate Service DCOM Access','Cert Publishers','Cloneable Domain Controllers','Cryptographic Operators','Denied RODC Password Replication Group','Distributed COM Users','DnsUpdateProxy','DnsAdmins','Domain Controllers','Enterprise Key Admins','Key Admins','Enterprise Read-Only Domain Controllers','Event Log Readers','Group Policy Creator Owners','Hyper-V Administrators','IIS_IUSRS','Network Configuration Operators','Pre–Windows 2000 Compatible Access','Print Operators','RAS and IAS Servers','Remote Management Users','Replicator','Server Operators')

    $htmlReport = ''
    $htmlReport += "<style>BODY{font-family: Arial; font-size: 8pt;}"
    $htmlReport += "TABLE{border: 1px solid black; border-collapse: collapse;}"
    $htmlReport += "TH{border: 1px solid black; background: #dddddd; padding: 2px; }"
    $htmlReport += "TD{border: 1px solid black; padding: 2px; }"
    $htmlReport +=  "</style>"   

    ForEach ($group In $ADGroup) {
        $htmlReport += "<table width=800>"
        $htmlReport += "<tr><th colspan='5'>Group - $group</th><tr>"
        $htmlReport += "<tr><th>Member</th><th>Enabled</th><th>Last logon</th><th>From</th><th>Path</th><tr>"
    
        Write-Verbose "Get members of $group ...."
        $Accounts = Get-ADGroupMembers -groupName $group
    
        ForEach ($Account In $Accounts) {
            $htmlReport += "<tr>"
            $htmlReport += "<td>$($Account.name)</td><td>$($Account.status)</td><td>$($Account.lastLogon)</td><td>$($Account.level)</td><td>$($Account.distinguishedName)</td>"
            $htmlReport += "</tr>"
        }    
    
        $htmlReport += '</table><br />'
    }
    Return $htmlReport
}

Function Get-DomainAdminAccount {
    $ReturnValue = ''
    
    $AdministratorSID = ((Get-ADDomain -Current LoggedOnUser).domainsid.value)+"-500"
    $AdministratorSAMAccountName = (Get-ADUser -Filter {SID -eq $AdministratorSID} -properties SamAccountName).SamAccountName
    
    if ($AdministratorSAMAccountName -eq "Administrator"){
       $ReturnValue += "<li>Local Administrator account (UID500) has not been renamed</li>"
    }
    elseif (!(Get-ADUser -Filter {samaccountname -eq "Administrator"})){
       $ReturnValue += "<li>Local Administrator account renamed to $AdministratorSAMAccountName.</li>"
    }

    $AdministratorLastLogonDate =  (Get-ADUser -Filter {SID -eq $AdministratorSID}  -properties lastlogondate).lastlogondate
    $ReturnValue += "<li>$AdministratorSAMAccountName last used $AdministratorLastLogonDate.</li>"

    Return $ReturnValue
}

Function Get-PasswordPolicy {
    $ReturnValue = '<table><tr><th>Setting</th><th>Recommended</th><th>Current settings</th><tr>'
    $passwordPolicy = Get-ADDefaultDomainPasswordPolicy
    $ReturnValue += "<tr><td>Password complexity</td><td>true</td><td>$($passwordPolicy.ComplexityEnabled)</td></tr>"
    $ReturnValue += "<tr><td>LockoutThreshold</td><td> >5</td><td>$($passwordPolicy.LockoutThreshold)</td></tr>"
    $ReturnValue += "<tr><td>MinPasswordLength</td><td> >14</td><td>$($passwordPolicy.MinPasswordLength)</td></tr>"
    $ReturnValue += "<tr><td>ReversibleEncryptionEnabled</td><td>False</td><td>$($passwordPolicy.ReversibleEncryptionEnabled)</td></tr>"
    $ReturnValue += "<tr><td>MaxPasswordAge</td><td> >0</td><td>$($passwordPolicy.MaxPasswordAge)</td></tr>"
    $ReturnValue += "<tr><td>PasswordHistoryCount</td><td> >5</td><td>$($passwordPolicy.PasswordHistoryCount)</td></tr>"

    $ReturnValue += '</table>'

    Return $ReturnValue
}

Function Get-AdminSDHolder {

    $protectedGroup = @('Account Operators','Administrators','Backup Operators','Cert Publishers','Domain Admins','Enterprise Admins','Print Operators','Schema Admins','Server Operators')

    $htmlReport = ''
    $htmlReport += "<style>BODY{font-family: Arial; font-size: 8pt;}"
    $htmlReport += "TABLE{border: 1px solid black; border-collapse: collapse;}"
    $htmlReport += "TH{border: 1px solid black; background: #dddddd; padding: 2px; }"
    $htmlReport += "TD{border: 1px solid black; padding: 2px; }"
    $htmlReport +=  "</style>"   

    $htmlReport += "<table width=800>"
    $htmlReport += "<tr><th colspan='4'>Admin SD Holder</th><tr>"
    $htmlReport += "<tr><th>Account</th><th>Enabled</th><th>Last logon</th><th>Path</th><tr>"

    $adminSDHolder = Get-AdObject -LdapFilter "(admincount=1)" -Properties enabled

    ForEach ($user In $adminSDHolder) {
        If ($User.objectclass -eq "user") {
            $userGroups = @()
        
            Try {
                $userGroups += (Get-ADPrincipalGroupMembership $user).Name 
            } Catch {
            }

            # kontrola jeslti neni v protected groups
            $equalGroup = 0
            If (-not (Compare-Object -ReferenceObject $protectedGroup -DifferenceObject $userGroups -IncludeEqual -ExcludeDifferent)) {
                Try {
                
                    $enabled = ''
                    $enabled = (Get-AdUser $user).enabled
                    write-host (Get-AdUser $user).enabled

                    $lastLogon = ''
                    $lastLogon = (Get-AdUser $user -properties lastlogondate).lastlogondate

                } Catch {
                    Continue
                }

                $htmlReport += "<tr>"
                $htmlReport += "<td>$($user.name)</td><td>$enabled</td><td>$lastLogon</td><td>$($user.distinguishedName)</td>"
                $htmlReport += "</tr>"
            }
        }
    }

    $htmlReport += '</table><br />'
    Return $htmlReport

}

#endfunction

$cssStyle = "
hr {
  border-top: 2px solid red;
}

table {
    border-collapse: collapse; 
    width: 100%; 
    border: 1px solid #ddd; 
    font-size: 12px; 
}
  
table th, table td {
  text-align: left; 
  padding: 5px; 
}

table tr {
  border-bottom: 1px solid #ddd;
}

table tr.header, table tr:hover {
  background-color: #9eb0d6;
} 

li {
 font-size: 16px; 
}
"

# inicialization
Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
$Error.Clear()

$htmlReport = ''
$htmlReport += "<html>"
$htmlReport += "<head>"
$htmlReport += "<style>$cssStyle</style>"
$htmlReport += "</head>"
$htmlReport += "<body>"

# reporty

Write-Verbose "AD group..."
$htmlReport += "<hr><h2>AD group</h2>"
$htmlReport += "<a href='https://docs.microsoft.com/en-us/windows/security/identity-protection/access-control/active-directory-security-groups'>link</a>"
$htmlReport += Get-ReportADGroup

Write-Verbose "Admin SD Holder ..."
$htmlReport += "<hr><h2>Admin SD Holder</h2>"
$htmlReport += Get-AdminSDHolder

Write-Verbose "Default administrator..."
$htmlReport += "<hr><h2>Default administrator</h2>"
$htmlReport += Get-DomainAdminAccount

Write-Verbose "Password policy..."
$htmlReport += "<hr><h2>Password policy</h2>"
$htmlReport += Get-PasswordPolicy 

$htmlReport += "</body>"
$htmlReport += "</html>"
$htmlReport | out-file report.html
