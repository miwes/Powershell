[CmdletBinding()]Param (
    [Parameter(Mandatory=$True,Position=1,ValueFromPipeline=$True)] [Alias("Server")] [string]$attrServer
)

$oldDNS = ("172.30.100.11", "172.30.100.12")
$newDNS = ("172.30.100.11", "172.30.120.12")

Try {
    $Session = New-CimSession -ComputerName $attrServer
    Get-DnsClientServerAddress -CimSession $Session | Where-Object {$_.AddressFamily -eq 2 -and [system.String]::Join(",",$_.ServerAddresses) -eq [system.String]::Join(",",$oldDNS)} | Set-DnsClientServerAddress -ServerAddresses $newDNS -CimSession $Session
    Get-DnsClientServerAddress -CimSession $Session | Where-Object {$_.AddressFamily -eq 2 }
} Catch {
    Write-Warning "Error = $($Error[0])"
}
