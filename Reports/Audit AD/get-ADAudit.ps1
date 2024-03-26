<#
.SYNOPSIS
    AD audit
    Version : 	
        1.0 - Init release
    	1.1 - Add more security groups
		1.2 - Add AdminSDHolder
        1.3 - Add Audit policy
        1.4 - add empty password, never expires
.DESCRIPTION
.NOTES
.LINK
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
    $ADGroup = @('Administrators','Domain Admins','Enterprise Admins','Schema Admins','Protected Users','Account Operators','Backup Operators','DnsAdmins','Domain Controllers','Enterprise Key Admins','Key Admins','Group Policy Creator Owners','Hyper-V Administrators','PreWindows 2000 Compatible Access','Print Operators')

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

Function Get-ADAuditPolicy {

$AuditPolicyReader = Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Linq;
using System.Collections.Generic;

public class AuditPolicyReader
{
    [Flags()]
    public enum AuditPolicySetting
    {
        Unknown =  -1,
        None    = 0x0,
        Success = 0x1,
        Failure = 0x2
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct LSA_UNICODE_STRING
    {
        public UInt16 Length;
        public UInt16 MaximumLength;
        public IntPtr Buffer;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct LSA_OBJECT_ATTRIBUTES
    {
        public int Length;
        public IntPtr RootDirectory;
        public LSA_UNICODE_STRING ObjectName;
        public UInt32 Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    public struct POLICY_AUDIT_EVENTS_INFO
    {
        public bool AuditingMode;
        public IntPtr EventAuditingOptions;
        public Int32 MaximumAuditEventCount;
    }

    [DllImport("advapi32.dll")]
    static extern uint LsaQueryInformationPolicy(IntPtr PolicyHandle, uint InformationClass, out IntPtr Buffer);

    [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
    static extern uint LsaOpenPolicy(ref LSA_UNICODE_STRING SystemName, ref LSA_OBJECT_ATTRIBUTES ObjectAttributes, uint DesiredAccess, out IntPtr PolicyHandle);

    [DllImport("advapi32.dll", SetLastError = true)]
    static extern uint LsaClose(IntPtr ObjectHandle);

    public static Dictionary<string, AuditPolicySetting> GetClassicAuditPolicy()
    {
        // Create dictionary to hold the audit policy settings (the key order here is important!!!)
        var settings = new Dictionary<string, AuditPolicySetting>
        {
            {"System", AuditPolicySetting.Unknown},
            {"Logon", AuditPolicySetting.Unknown},
            {"Object Access", AuditPolicySetting.Unknown},
            {"Privilige Use", AuditPolicySetting.Unknown},
            {"Detailed Tracking", AuditPolicySetting.Unknown},
            {"Policy Change", AuditPolicySetting.Unknown},
            {"Account Management", AuditPolicySetting.Unknown},
            {"Directory Service Access", AuditPolicySetting.Unknown},
            {"Account Logon", AuditPolicySetting.Unknown},
        };

        // Open local machine security policy
        IntPtr polHandle;
        LSA_OBJECT_ATTRIBUTES aObjectAttributes = new LSA_OBJECT_ATTRIBUTES();
        aObjectAttributes.Length = 0;
        aObjectAttributes.RootDirectory = IntPtr.Zero;
        aObjectAttributes.Attributes = 0;
        aObjectAttributes.SecurityDescriptor = IntPtr.Zero;
        aObjectAttributes.SecurityQualityOfService = IntPtr.Zero;

        var systemName = new LSA_UNICODE_STRING();
        uint desiredAccess = 2; // we only need the audit policy, no need to request anything else
        var res = LsaOpenPolicy(ref systemName, ref aObjectAttributes, desiredAccess, out polHandle);
        if (res != 0)
        {
            if(res == 0xC0000022)
            {
                // Access denied, needs to run as admin
                throw new UnauthorizedAccessException("Failed to open LSA policy because of insufficient access rights");
            }
            throw new Exception(string.Format("Failed to open LSA policy with return code '0x{0:X8}'", res));
        }
        try
        {
            // now that we have a valid policy handle, we can query the settings of the audit policy
            IntPtr outBuffer;
            uint policyType = 2; // this will return information about the audit settings
            res = LsaQueryInformationPolicy(polHandle, policyType, out outBuffer);
            if (res != 0)
            {
                throw new Exception(string.Format("Failed to query LSA policy information with '0x{0:X8}'", res));
            }

            // copy the raw values returned by LsaQueryPolicyInformation() to a local array;
            var auditEventsInfo = Marshal.PtrToStructure<POLICY_AUDIT_EVENTS_INFO>(outBuffer);
            var values = new int[auditEventsInfo.MaximumAuditEventCount];                
            Marshal.Copy(auditEventsInfo.EventAuditingOptions, values, 0, auditEventsInfo.MaximumAuditEventCount);

            // now we just need to translate the provided values into our settings dictionary
            var categoryIndex = settings.Keys.ToArray();
            for (int i = 0; i < values.Length; i++)
            {
                settings[categoryIndex[i]] = (AuditPolicySetting)values[i];
            }

            return settings;
        }
        finally
        {
            // remember to release policy handle
            LsaClose(polHandle);
        }
    }
}
'@ -PassThru | Where-Object Name -eq AuditPolicyReader
    $auditPolicy = $AuditPolicyReader::GetClassicAuditPolicy()
    
    $htmlReport = ''
    $htmlReport += "<style>BODY{font-family: Arial; font-size: 8pt;}"
    $htmlReport += "TABLE{border: 1px solid black; border-collapse: collapse;}"
    $htmlReport += "TH{border: 1px solid black; background: #dddddd; padding: 2px; }"
    $htmlReport += "TD{border: 1px solid black; padding: 2px; }"
    $htmlReport +=  "</style>"   

    $htmlReport += "<table width=800>"
    $htmlReport += "<tr><th colspan='4'>Audit policy</th><tr>"
    $htmlReport += "<tr><th>Audit</th><th>Settings</th><tr>"
 
    ForEach ($policy In $auditPolicy.Keys) {
        
        $htmlReport += "<tr>"
        $htmlReport += "<td>$policy</td><td>$($auditPolicy.$policy)</td>"
        $htmlReport += "</tr>"
    }
    
    $htmlReport += '</table><br />'
    Return $htmlReport

}

Function Get-NeverExpiresPassword {
    
    
    $users = Get-ADUser -filter * -properties Name, PasswordNeverExpires | where {$_.passwordNeverExpires -eq "true" }

    $htmlReport = ''
    $htmlReport += "<style>BODY{font-family: Arial; font-size: 8pt;}"
    $htmlReport += "TABLE{border: 1px solid black; border-collapse: collapse;}"
    $htmlReport += "TH{border: 1px solid black; background: #dddddd; padding: 2px; }"
    $htmlReport += "TD{border: 1px solid black; padding: 2px; }"
    $htmlReport +=  "</style>"   

    $htmlReport += "<table width=800>"
    $htmlReport += "<tr><th colspan='4'>Account with a password which never expires</th><tr>"
    $htmlReport += "<tr><th>Account</th><th>Enabled</th><th>Last logon</th><th>Path</th><tr>"
    
    ForEach ($user In $users) {
        Try {
                
            $enabled = ''
            $enabled = (Get-AdUser $user).enabled

            $lastLogon = ''
            $lastLogon = (Get-AdUser $user -properties lastlogondate).lastlogondate

        } Catch {
            Continue
        }

        $htmlReport += "<tr>"
        $htmlReport += "<td>$($user.name)</td><td>$enabled</td><td>$lastLogon</td><td>$($user.distinguishedName)</td>"
        $htmlReport += "</tr>"
     }
    

    $htmlReport += '</table><br />'
    Return $htmlReport  
}

Function Get-CanEmptyPassword {
    
    
    $users = Get-ADUser -Filter {PasswordNotRequired -eq $true}

    $htmlReport = ''
    $htmlReport += "<style>BODY{font-family: Arial; font-size: 8pt;}"
    $htmlReport += "TABLE{border: 1px solid black; border-collapse: collapse;}"
    $htmlReport += "TH{border: 1px solid black; background: #dddddd; padding: 2px; }"
    $htmlReport += "TD{border: 1px solid black; padding: 2px; }"
    $htmlReport +=  "</style>"   

    $htmlReport += "<table width=800>"
    $htmlReport += "<tr><th colspan='4'>Account which can have an empty password - userAccountControl PASSWD_NOTREQD</th><tr>"
    $htmlReport += "<tr><th>Account</th><th>Enabled</th><th>Last logon</th><th>Path</th><tr>"
    
    ForEach ($user In $users) {
        Try {
                
            $enabled = ''
            $enabled = (Get-AdUser $user).enabled

            $lastLogon = ''
            $lastLogon = (Get-AdUser $user -properties lastlogondate).lastlogondate

        } Catch {
            Continue
        }

        $htmlReport += "<tr>"
        $htmlReport += "<td>$($user.name)</td><td>$enabled</td><td>$lastLogon</td><td>$($user.distinguishedName)</td>"
        $htmlReport += "</tr>"
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

Write-Verbose "Audit policy..."
$htmlReport += "<hr><h2>Audit policy</h2>"
Try {
    $htmlReport += Get-ADAuditPolicy
} Catch {
    
}

Write-Verbose "Account never expires ..."
$htmlReport += "<hr><h2>Account never expires</h2>"
$htmlReport += Get-NeverExpiresPassword

Write-Verbose "Account which can have an empty password ..."
$htmlReport += "<hr><h2>Account which can have an empty password</h2>"
$htmlReport += Get-CanEmptyPassword


$htmlReport += "</body>"
$htmlReport += "</html>"
$htmlReport | out-file report.html
