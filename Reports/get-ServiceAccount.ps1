$servers = Get-ADComputer -Filter * -SearchBase "OU=Servery,DC=ad,DC=cz" -SearchScope Subtree
$services = ForEach ($server In $servers) {
    Write-Host $server.name
    Try {
        Get-WmiObject win32_service -ComputerName $server.name | Where-Object {$_.startname -like "*kovo*"} | Select-Object PSComputerName, Name, Startname
    } Catch {
        Write-Host $Error[0]
    }
}

$services | Out-GridView
