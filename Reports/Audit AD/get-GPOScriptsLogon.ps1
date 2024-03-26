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

$scripts = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -Include scripts.ini -Hidden
$report = @{}
ForEach ($script In $scripts) {
    $contain = Get-IniContent $script

    Try {
        ForEach ($line In $contain.logon.GetEnumerator()) {
            If ($line.value) {
                $GPOID = $script.PSPath.Split("{").split("}")[1]
                #$line.value
                $GPOName= (Get-GPO -GUID $GPOID).DisplayName
                $report.Add($line.value, $GPOName)
            }
        }
    } Catch {
    }
}
$report | Out-GridView