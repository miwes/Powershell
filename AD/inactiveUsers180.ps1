$d = [DateTime]::Today.AddDays(-180)
Get-ADUser -Filter '(LastLogonTimestamp -lt $d) -and (Enabled -eq $true)' -Properties PasswordLastSet,LastLogonTimestamp | ft Name,PasswordLastSet,@{N="LastLogonTimestamp";E={[datetime]::FromFileTime($_.LastLogonTimestamp)}}
