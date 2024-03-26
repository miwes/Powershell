$path = '\\domane.int\SYSVOL\domane.int\Policies\'


$scripts = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Include Files.xml 


$report = @()

ForEach ($script In $scripts) {

    $GPOID = $script.PSPath.Split("{").split("}")[1]
    $GPOName= (Get-GPO -GUID $GPOID).DisplayName

    [xml]$contain = Get-Content $script
    ForEach ($file In $contain.Files.File) {
        $file.name
        $file.Properties.action
        $file.Properties.targetPath
        
        $oFile = New-Object psobject

        $oFile | Add-Member -MemberType NoteProperty -Name 'GPOName' -Value $GPOName
        $oFile | Add-Member -MemberType NoteProperty -Name 'File' -Value $file.name
        $oFile | Add-Member -MemberType NoteProperty -Name 'Action' -Value $file.Properties.action
        $oFile | Add-Member -MemberType NoteProperty -Name 'TargetPath' -Value $file.Properties.targetPath
        
        $report += $oFile        
    }

    Write-host '----------'

}
$report | Out-GridView