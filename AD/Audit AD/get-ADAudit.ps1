<#
.SYNOPSIS
    AD audit
    Version : 	1.0 - Init release
    		1.1 - Add more security groups
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
                    $enabled = (Get-AdUser $member).enabled
                } ElseIf ( $User.objectclass -eq "computer") {
                    $enabled = (Get-ADComputer $member).enabled
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
        $htmlReport += "<tr><th colspan='3'>Group - $group</th><tr>"
        $htmlReport += "<tr><th>Member</th><th>Enabled</th><th>From</th><tr>"
    
        Write-Verbose "Get members of $group ...."
        $Accounts = Get-ADGroupMembers -groupName $group
    
        ForEach ($Account In $Accounts) {
            $htmlReport += "<tr>"
            $htmlReport += "<td>$($Account.name)</td><td>$($Account.status)</td><td>$($Account.level)</td>"
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

Write-Verbose "Default administrator..."
$htmlReport += "<hr><h2>Default administrator</h2>"
$htmlReport += Get-DomainAdminAccount

Write-Verbose "Password policy..."
$htmlReport += "<hr><h2>Password policy</h2>"
$htmlReport += Get-PasswordPolicy 

$htmlReport += "</body>"
$htmlReport += "</html>"
$htmlReport | out-file report.html
