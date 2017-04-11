<# 
.SYNOPSIS 
    Skript pro import uzivatelu z CSV do AD
.DESCRIPTION 
    Skript vytvori uzivatele v AD dle CSV souboru. 
    Soubor CSV ma strukturu Jmeno;prijmeni;trida;heslo, v CSV souboru se ocekava hlavicka.
    Jako oddelovac muze byt pouzity jakykoli znak, vychozi je strednik.
    
    Priklad CSV souboru:
        Jmeno;prijmeni;trida;heslo
        Jarda;Novak;5A;JHeslo12345
        
.NOTES 
    Author      :  Michal Weis
    Version     :  v1.4.1
    Create date	:  3.8.2016
.LINK 
.EXAMPLE 
.PARAMETER FileCSV
    Cesta + jmeno CSV souboru
.PARAMETER FileLog
    Cesta + jmeno log souboru
.PARAMETER CSVDelimiter
    Delimiter/oddelovac CSV souboru
.PARAMETER OU
    OU ve ktere maji byt uzivatele vytvoreni
.PARAMETER GroupsName
    Skupiny do kterych maji byt uzivatele cleny. Je mozne vlozit vice skupin
    Priklad @('Zaci','Skola','Email')

#>

[CmdletBinding()]
Param(
        [Parameter(Mandatory=$False)] [string]$FileCSV = 'SEZNAM1strednik.csv'
       ,[Parameter(Mandatory=$False)] [string]$FileLog = 'log.txt'
       ,[Parameter(Mandatory=$False)] [string]$CSVDelimiter = ';'
       ,[Parameter(Mandatory=$False)] [string]$OU = 'OU=Zaci,OU=05252,DC=D05252,DC=idva,DC=cz'
       ,[Parameter(Mandatory=$False)] [object]$GroupsName = @('SKUPINA-Zaci')
)
Set-StrictMode -Version Latest
$Error.Clear()

#Region Function

<# 
.SYNOPSIS 
    Funkce prida radek textu do log souboru.
.DESCRIPTION 
    Pokud nelze zapsat do log souboru, skript je ukoncen.
.PAREMETER FileLog
    Cesta + jmeno log soubor
.PARAMETER Text
    Text radku
#>
Function Add-LogToFile
{
    Param
    (
        [Parameter(Mandatory=$true)][string]$FileLog,
        [Parameter(Mandatory=$true)][string]$Text
    )

    $date = Get-Date
    $text = $date.ToString() + ";" + $text

    try {
        $text | out-file $fileLog -Append    
    }
    catch  {
        Write-Warning "Nelze zapisovat do log souboru. Skript je ukoncen."
        Exit;
    }
}

<# 
.SYNOPSIS 
    Funkce nahraje definovy powershell modul.
.DESCRIPTION 
    Pokud modul neni dostupny, fuknce vraci false.
.PAREMETER sModule
    Jmeno powershell modulu
#>
Function Add-Module
{
    Param
    (
        [Parameter(Mandatory=$true)][Alias('Module')][string]$sModule 
    )

    If (Get-Module -ListAvailable -Name $sModule) 
    {
        Import-Module $sModule
        Return $True
    }
    Else 
    {
        Write-Warning "[Error] fn. Load-Module : Module $sModule neexistuje."
        Return $False
    }
}

<# 
.SYNOPSIS 
    Funkce nacte obsah CSV souboru
.DESCRIPTION 
.PAREMETER FileCSV
    Cesta + jmeno k csv souboru
.PARAMETER CSVDelimiter
    Delimiter(oddelovac), ktery je pouzit v CSV souboru
#>
Function Read-CSV
{
    Param
    (
         [Parameter(Mandatory=$True)] [string]$FileCSV
        ,[Parameter(Mandatory=$False)] [string]$CSVDelimiter
    )
    $DataUsers = Import-Csv -Path $FileCSV -Delimiter $CSVDelimiter
    Return $DataUsers
}

<# 
.SYNOPSIS 
    Funkce tesxtuje existenci AD uzivatele
.DESCRIPTION
    Pokud uzivatel existuje vraci true. 
.PAREMETER Username
    Username uzivatele
#>
Function Test-User
{
    Param 
    (
        [Parameter(Mandatory=$True)] [string]$Username   
    )

    Try {
        Get-ADUser $Username
    }
    Catch {
        Return $False
    }
    Return $True

}

function Remove-StringLatinCharacters
{
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}

#endregion

Add-LogToFile -text "Info;Start skriptu" -FileLog $FileLog

Write-Progress -Activity 'Importuji uzivatele do AD' -Status 'Importuji AD moduly do Powershellu'
Write-Verbose 'Importuji AD moduly do Powershellu'
If (!(Add-Module -Module 'ActiveDirectory'))
{
    Exit;
}

Write-Progress -Activity 'Importuji uzivatele do AD' -Status "Testuji existenci CSV souboru :$FileCSV" 
Write-Verbose "Testuji existenci CSV souboru :$FileCSV" 
If (!(Test-Path -Path $FileCSV))
{
    Write-Warning 'CSV soubor neni dostupny'
    Exit;
}

Write-Progress -Activity 'Importuji uzivatele do AD' -Status "Importuji CSV soubor : $FileCSV"
Write-Verbose "Importuji CSV soubor : $FileCSV"
$DataUsers = Read-CSV -FileCSV $FileCSV -CSVDelimiter $CSVDelimiter

Write-Verbose 'Zakladam uzivatele'
#Write-progress promenna
$i = 0
ForEach ($Row In $DataUsers)
{
    Write-Progress -Activity 'Importuji uzivatele do AD' -Status 'Zakladam uzivatele' -PercentComplete (($i++/$DataUsers.count) *100) 

    # sloz uzivatelske jmeno - 4znaky prijmeni + 2 znakyjmeno
    [string]$Username = '' 
    If ($Row.Prijmeni.Length -le 4 ) {
        $UserName = $Row.Prijmeni
    }
    Else {
        $UserName = $Row.Prijmeni.Substring(0,4)
    }
    $UserName += $Row.Jmeno.Substring(0,2)
    # odeber diakritiku
    $UserName = Remove-StringLatinCharacters $UserName

    # prekonvertuj heslo
    [securestring]$Password = $null
    $Password = ConvertTo-SecureString -String $Row.heslo -AsPlainText -Force 

    Add-LogToFile -Text "Info;Zakladam uzivatele $Username" -FileLog $FileLog
    
    Write-Verbose "Testuji exitenci uzivatele $Username"
    If ((Test-User -Username $Username) -eq $true)
    {
        Add-LogToFile -Text "Error;Uzivatel $username existuje" -FileLog $FileLog
        Write-Warning "Uzivatel $username existuje"
    }
    Else {
        Write-Verbose "Zakladam uzivatele $Username"
        Try {
            $DisplayName = $row.prijmeni + ' ' + $row.jmeno
            New-ADUser -UserPrincipalName $username -Name $UserName -GivenName $row.jmeno -Surname $row.prijmeni -DisplayName $DisplayName -Description "$($Row.jmeno) $($row.prijmeni) $($row.trida)" -AccountPassword $Password -Path $OU -Enabled $true -ErrorAction Stop 
            Add-LogToFile -Text "Info;Uzivatel $Username uspesne zalozen" -FileLog $FileLog

            Write-Verbose "Pridavam uzivatele $username do skupin"
            $Groups = @()
            $Groups += $GroupsName
            $Groups += $row.trida.Trim()
            ForEach ($Group In $Groups){
                Try {
                    Add-AdGroupMember -Identity $Group -Members $Username
                }
                Catch {
                    Add-LogToFile -text "Error;Chyba pri pridavani uzivatele $Username do skupiny $group;$($error[0].Exception.Message)" -FileLog $FileLog
                    Write-Warning "Chyba pri pridavani uzivatele $username do skupiny $group"
                }
            }
        }
        Catch {
            Add-LogToFile -text "Error;Chyba pri zakladani uzivatele $username;$($error[0].Exception.Message)" -FileLog $FileLog
            Write-Warning "Chyba pri zalozeni $Username"    
        }
    }
}
