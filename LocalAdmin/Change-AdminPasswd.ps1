[CmdletBinding()]Param (
    [Parameter(Mandatory=$True,Position=1)] [Alias("ServerName")] [string]$attrServerName
    ,[Parameter(Mandatory=$True,Position=2)] [Alias("Passwd")] [string]$attrPasswd
)

Invoke-Command -ComputerName $attrServerName -ArgumentList $attrPasswd -ScriptBlock { Param($passwd) net user administrator $passwd } 