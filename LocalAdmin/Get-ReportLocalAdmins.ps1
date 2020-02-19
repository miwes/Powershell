<# 
.SYNOPSIS 
    report lokalnich administratoru
.DESCRIPTION 
    
.NOTES 
    Author: Michal Weis
    Version : 2.0
.LINK 
.EXAMPLE 
.PARAMETER

#>

$group = "Administrators"
$fileXML = "$PWD\report.xml"
$fileServers =  "$PWD\servery.txt"

Function Get-LocalGroup
{
    Param
    (
        [Parameter(Mandatory = $true,Position = 0,valueFromPipeline=$true)][string]$GroupName,
        [Parameter(Mandatory = $true,Position = 1,valueFromPipeline=$true)][string]$Server
    )

    Try
    {
        $group = [ADSI]"WinNT://$server/$GroupName"
        $members = @($group.Invoke("Members"))
    }
    Catch
    {
		Write-Host $Error[0]
        Return $false
    }
    
    $record = @()

    ForEach ($member in $Members)
    {
        $MemberName = $member.GetType().Invokemember("Name","GetProperty",$null,$member,$null)
        $MemberType = $member.GetType().Invokemember("Class","GetProperty",$null,$member,$null)
        $MemberPath = $member.GetType().Invokemember("ADSPath","GetProperty",$null,$member,$null)
        Try
        {
            $MemberDescription = $member.GetType().Invokemember("Description","GetProperty",$null,$member,$null)
        }
        Catch
        {
            $MemberDescription = ""
        }
        
        # vylouceni uctu computer
        If ($MemberName -notlike '*$')
        {
            $event = New-Object PSObject
            $event | Add-Member -MemberType NoteProperty -Name Server -Value $server
            $event | Add-Member -MemberType NoteProperty -Name Username -Value $MemberName
            $event | Add-Member -MemberType NoteProperty -Name Type -Value $MemberType
            $event | Add-Member -MemberType NoteProperty -Name Description -Value $MemberDescription
            $event | Add-Member -MemberType NoteProperty -Name Domain -Value $MemberPath
            $record += $event
        }
    }
    Return $Record
}

$Servers = (Get-Content -Path $fileServers)
$ReportXML = New-Object System.XMl.XmlTextWriter($fileXML,$Null)
$ReportXML.Formatting = 'Indented'
$ReportXML.Indentation = 1
$ReportXML.IndentChar = "`t"
$ReportXML.WriteStartDocument()
$ReportXML.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='report.xslt'")
$ReportXML.WriteStartElement('Report')
$ReportXML.WriteAttributeString('Group',$Group)

$i = 1
ForEach ($server In $Servers)
{
    $ReportXML.WriteStartElement('Server')
    $ReportXML.WriteAttributeString('Name', $Server)
    Write-Progress -Activity "Scan computer" -CurrentOperation "$server" -PercentComplete (($i++/$Servers.Count) *100)
    $Record = Get-LocalGroup -GroupName $group -server $server
    If ($Record -ne $false)
    {
        ForEach($object in $record)
        {
            $ReportXML.WriteStartElement('Name')
            $ReportXML.WriteAttributeString('Value',$object.Username)
            $ReportXML.WriteElementString('Type',$object.Type)
            $ReportXML.WriteElementString('Description',$object.Description)
            $ReportXML.WriteElementString('Domain',$object.Domain)
            $ReportXML.WriteEndElement()
        }
    }Else
    {
        $ReportXML.WriteStartElement('Name')
        $ReportXML.WriteAttributeString('Value','Cannoct connect!')
        $ReportXML.WriteEndElement()
    }
    $ReportXML.WriteEndElement()
}
$ReportXML.WriteEndElement()

$ReportXML.Close()
