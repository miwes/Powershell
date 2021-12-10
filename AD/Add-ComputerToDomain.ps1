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
    [Parameter(Mandatory=$False,Position=8)] [Alias("VMName")] [string]$attrVMName = 'server'
    ,[Parameter(Mandatory=$False,Position=1)] [Alias("IP")] [string]$attrIP = '172.16.10.1'
    ,[Parameter(Mandatory=$False,Position=2)] [Alias("GW")] [string]$attrGW = '172.16.10.2'
    ,[Parameter(Mandatory=$False,Position=3)] [Alias("NETMASK")] [string]$attrNetmask = 16
    ,[Parameter(Mandatory=$False,Position=4)] [Alias("DNS")] [string]$attrDNS = ('172.16.10.132')
    ,[Parameter(Mandatory=$False,Position=5)] [Alias("DomainName")] [string]$attrDomain = 'test.local'
    ,[Parameter(Mandatory=$False,Position=6)] [Alias("Account")] [string]$attrAccount = 'test.local\domainjoin'
    ,[Parameter(Mandatory=$False,Position=7)] [Alias("LocalPassword")] [string]$attrLocalAccountPassword = 'Heslo12345'
)


Set-StrictMode -Version latest

Write-Verbose "Connect to $attrVMName"
Try {
    $sp = ConvertTo-SecureString $attrLocalAccountPassword -asplaintext -force
    $credent = New-Object System.Management.Automation.PSCredential('.\administrator',$sp)
    $session = New-PSSession -VMName $attrVMName -credential $credent 
    $cred = get-credential $attrAccount
} Catch {
    Write-Warning $Error[0]
    Exit
}

Write-Verbose "Setting IP $attrIP"
Invoke-Command -Session $session {
    Param ($attrIP,$attrNetmask,$attrGW) 
    New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress $attrIP -PrefixLength $attrNetmask -DefaultGateway $attrGW 
} -ArgumentList ($attrIP,$attrNetmask,$attrGW)

Write-Verbose "Setting DNS $attrDNS"
Invoke-Command -Session $session {
    Param ($attrDNS)
    Set-DNSClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses $attrDNS
} -ArgumentList ($attrDNS)

Write-Verbose "Setting High Performance, disable IPv6, disable FW, disable services"
Invoke-Command -Session $session {
    $p = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'High Performance'" 
    Invoke-CimMethod -InputObject $p -MethodName Activate
    
    New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0xffffffff -PropertyType "DWord"  

    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False 

    Stop-Service -Name 'DiagTrack' –Force 
    Stop-Service -Name 'Mapsbroker' -Force 
    Set-Service -Name 'DiagTrack' -StartupType Disabled 
    Set-Service -Name 'Mapsbroker' -StartupType Disabled 
}

Write-Verbose "Add to domain $attrDomain, rename and restart"
Invoke-Command -Session $session { 
    Param ($attrDomain,$cred)
    Add-Computer -DomainName $attrDomain -Credential $cred 
    Start-Sleep -seconds 15
    $VMName = (Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters"  | Select-Object VirtualMachineName).VirtualMachineName
    Rename-Computer -NewName $VMName -DomainCredential $cred -Restart
} -ArgumentList ($attrDomain,$cred)

