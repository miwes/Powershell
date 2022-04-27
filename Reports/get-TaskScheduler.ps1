<#
.Synopsis
   PowerShell script to list all Scheduled Tasks and the User ID
.DESCRIPTION
   This script scan the content of the c:\Windows\System32\tasks and search the UserID XML value. 
   The output of the script is a comma-separated log file containing the Computername, Task name, UserID.
#>

#Import-Module ActiveDirectory
$VerbosePreference = "continue"
#$list = (Get-ADComputer -LDAPFilter "(&(objectcategory=computer)(OperatingSystem=*server*))").Name
$logfilepath = "$home\Desktop\TasksLog.csv"
$ErrorActionPreference = "SilentlyContinue"

#$servers =  @('rds02','rds01')
$servers = Get-ADComputer -Filter * -SearchBase "OU=Servery,DC=ad,DC=cz" -SearchScope Subtree

ForEach ($computername In $servers.name)
{
    Write-Verbose $computername
    $path = "\\" + $computername + "\c$\Windows\System32\Tasks"
    $tasks = Get-ChildItem -Path $path -File

    if ($tasks)
    {
        Write-Verbose -Message "I found $($tasks.count) tasks for $computername"
    }

    foreach ($item in $tasks)
    {
        $AbsolutePath = $path + "\" + $item.Name
        $task = [xml] (Get-Content $AbsolutePath)
        [STRING]$check = $task.Task.Principals.Principal.UserId

        if ($task.Task.Principals.Principal.UserId)
        {
          Write-Verbose -Message "Writing the log file with values for $computername"           
          Add-content -path $logfilepath -Value "$computername,$item,$check"
        }

    }
}