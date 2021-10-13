Get-AdUser -Filter * -Properties * | Select Name,GivenName,Surname,userPrincipalName,Description,SamAccountName,mail,Department,distinguishedName,homeDirectory,scriptPath,whenChanged | Export-Csv -Path .\FL-Users.csv -NoTypeInformation -Encoding UTF8

Get-AdGroup -Filter * -Properties * | Select Name,GroupCategory,GroupScope,mail,distinguishedName | Export-Csv -Path .\FL-Group.csv -NoTypeInformation -Encoding UTF8