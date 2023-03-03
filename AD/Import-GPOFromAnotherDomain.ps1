Import-Module ActiveDirectory            
Import-Module GroupPolicy  

$Folder = 'C:\AC\GPO-28022023\GPO-28022023'
$GPOs = Get-ChildItem $Folder | Select name

foreach ($ID in $GPOs) {
    $XMLFile = $Folder + "\" + $ID.Name + "\gpreport.xml"
    $XMLData = [XML](get-content $XMLFile)
    $GPOName = $XMLData.GPO.Name.ToString().Replace('BIO - ','SN - ')
        
    Import-Gpo -BackupId $ID.Name -TargetName $GPOName -path $Folder -CreateIfNeeded
}