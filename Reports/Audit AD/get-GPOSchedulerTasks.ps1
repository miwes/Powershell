$path = '\\domane.int\SYSVOL\domane.int\Policies\'


$scripts = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Include ScheduledTasks.xml

$report = @()
ForEach ($script In $scripts) {

    $GPOID = $script.PSPath.Split("{").split("}")[1]
    $GPOName= (Get-GPO -GUID $GPOID).DisplayName
    [xml]$GPOSettings = Get-Content $script

    ForEach ($task In $GPOSettings.ScheduledTasks) {

        $oTask = New-Object psobject
        $oTask | Add-Member -MemberType NoteProperty -Name 'GPOName' -Value $GPOName
        If ($task.TaskV2) {
            $oTask | Add-Member -MemberType NoteProperty -Name 'Name' -Value $task.TaskV2.Properties.Name
            $oTask | Add-Member -MemberType NoteProperty -Name 'Command' -Value $task.TaskV2.Properties.Task.Actions.Exec.Command
            $oTask | Add-Member -MemberType NoteProperty -Name 'Arguments' -Value $task.TaskV2.Properties.Task.Actions.Exec.Arguments
        }
        Else {
            $oTask | Add-Member -MemberType NoteProperty -Name 'Name' -Value $task.Properties.Name
            $oTask | Add-Member -MemberType NoteProperty -Name 'Command' -Value $task.Properties.Task.Actions.Exec.Command
            $oTask | Add-Member -MemberType NoteProperty -Name 'Arguments' -Value $task.Properties.Task.Actions.Exec.Arguments
        }
        $report += $oTask        
    }
}
$report | Out-GridView