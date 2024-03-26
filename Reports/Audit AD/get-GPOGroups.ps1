$path = '\\domane.int\SYSVOL\domane.int\Policies\'

function Get-IniContent ($filePath)
{
	$ini = @{}
	switch -regex -file $FilePath
	{
    	“^\[(.+)\]” # Section
    	{
        	$section = $matches[1]
        	$ini[$section] = @{}
        	$CommentCount = 0
    	}
    	“^(;.*)$” # Comment
    	{
        	$value = $matches[1]
        	$CommentCount = $CommentCount + 1
        	$name = “Comment” + $CommentCount
        	$ini[$section][$name] = $value
    	}
    	“(.+?)\s*=(.*)” # Key
    	{
        	$name,$value = $matches[1..2]
        	$ini[$section][$name] = $value
    	}
	}
	return $ini
}

function get-SIDtoName ($SID) {
    $SID = New-Object System.Security.Principal.SecurityIdentifier($SID)
    Return $SID.Translate([System.Security.Principal.NTAccount])
}

#GPP nastaveni
$scripts = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Include Groups.xml
$report = @()
ForEach ($script In $scripts) {

    $GPOID = $script.PSPath.Split("{").split("}")[1]
    $GPOName= (Get-GPO -GUID $GPOID).DisplayName
    [xml]$GPOSettings = Get-Content $script
  
    ForEach ($group In $GPOSettings.Groups.Group) {

        ForEach ($member In $GPOSettings.Groups.Group.Properties.Members.Member) {
            $member
            $oGroup = New-Object psobject
            $oGroup | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'GPP'
            $oGroup | Add-Member -MemberType NoteProperty -Name 'GPOName' -Value $GPOName
            $oGroup | Add-Member -MemberType NoteProperty -Name 'Name' -Value $group.name
            $oGroup | Add-Member -MemberType NoteProperty -Name 'Groupname' -Value $group.Properties.groupName
            $oGroup | Add-Member -MemberType NoteProperty -Name 'Action' -Value $group.Properties.action
            $oGroup | Add-Member -MemberType NoteProperty -Name 'Members' -Value $member.name
            $oGroup | Add-Member -MemberType NoteProperty -Name 'Filter' -Value $group.Filters.OuterXml

            $report += $oGroup
        }
    }
}

# Restricted group settings
$rgs = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Include GptTmpl.inf

ForEach ($script In $rgs) {
    $GPOID = $script.PSPath.Split("{").split("}")[1]
    $GPOName= (Get-GPO -GUID $GPOID).DisplayName
    $Settings = Get-IniContent $script
    
    If ($Settings."Group Membership") {
        
        ForEach ($set in $Settings."Group Membership".GetEnumerator()) {
            [string]$Group = $set.Name.ToString().trim().replace('*','') | where{$_ -ne ""}
            [string]$Member = $set.Value.ToString().trim().replace('*','') | where{$_ -ne ""}
            
            if ($Member) {
                $groupSID  = $group.split('__')[0]
                $groupDes  = $group.split('__')[2]

                $GroupName = get-SIDtoName ($member)
                $Members = get-SIDtoName ($groupSID)

                $oGroup = New-Object psobject
                $oGroup | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'Restricted groups'
                $oGroup | Add-Member -MemberType NoteProperty -Name 'GPOName' -Value $GPOName
                $oGroup | Add-Member -MemberType NoteProperty -Name 'Groupname' -Value $GroupName
                $oGroup | Add-Member -MemberType NoteProperty -Name 'Action' -Value $groupDes
                $oGroup | Add-Member -MemberType NoteProperty -Name 'Members' -Value $Members
                $report += $oGroup
            }

        }
    }
}
$report | Out-GridView