$path = '\\domane.int\SYSVOL\domane.int\Policies\'


$scripts = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Include *.aas 

$report = @()


ForEach ($script In $scripts) {

    $GPOID = $script.PSPath.Split("{").split("}")[1]
    $GPOName= (Get-GPO -GUID $GPOID).DisplayName
    $GPOSettings = Get-GPOReport -GUID $GPOID -ReportType Xml

    $matches = $GPOSettings | Select-String -Pattern '(?s)<q\d+:Path>(.*?)</q\d+:Path>' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }

    # Výpis nalezených řetězců
    foreach ($match in $matches) {
        $oFile = New-Object psobject

        $oFile | Add-Member -MemberType NoteProperty -Name 'GPOName' -Value $GPOName
        $oFile | Add-Member -MemberType NoteProperty -Name 'File' -Value $match
        
        $report += $oFile        
    }
}
$report | Out-GridView