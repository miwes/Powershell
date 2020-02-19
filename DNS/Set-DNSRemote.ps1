[CmdletBinding()]Param (
    [Parameter(Mandatory=$True,Position=1)] [Alias("Server")] [string]$attrServer
)

$oldDNS = "192.168.169.12"
$newDNS = ("172.16.10.11", "172.16.138.11")

Try {
    $Session = New-CimSession -ComputerName $attrServer #-Authentication Kerberos
    Get-DnsClientServerAddress -CimSession $Session | Where-Object {$_.AddressFamily -eq 2 -and [system.String]::Join(",",$_.ServerAddresses) -eq $oldDNs} | Set-DnsClientServerAddress -ServerAddresses $newDNS -CimSession $Session
    Get-DnsClientServerAddress -CimSession $Session | Where-Object {$_.AddressFamily -eq 2 }
} Catch {
    Write-Warning "Error = $($Error[0])"
}
