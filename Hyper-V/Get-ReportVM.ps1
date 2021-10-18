<#
.SYNOPSIS
    Inventory VM from Hyper-V
.DESCRIPTION
.NOTES
.LINK
.EXAMPLE
.PARAMETER foo
.PARAMETER bar
#>

<# TODO

#>

[CmdletBinding()]Param (
    [Parameter(Mandatory=$True)] [string]$attrHyperV
    ,[Parameter(Mandatory=$False)] [boolean]$attrCluster = $False
    ,[Parameter(Mandatory=$False)] [string]$attrReportFile = '.\report.csv'
)

# inicialization
Set-StrictMode -Version latest
$global:ErrorActionPreference = 'Stop'
$Error.Clear()

If ($attrCluster -eq $True) {
    $nodes = Get-ClusterNode -Cluster $attrHyperV
} Else {
    $nodes = $attrHyperV
}

$Report = @()

ForEach ($node in $nodes) {
    
    Write-Verbose "Get data from $node ..."

    $VMs = Get-VM -ComputerName $node
        
    ForEach ($VM In $VMs) {

        Write-Verbose "Getting information about $($VM.Name) ... "
        
        $Data = '' | Select-Object Name, State, MemoryMB, PathVM, CPUCount, Version, ` 
            NetworkSwitch,NetworkStatus,NetworkVLANID, `
            "Path disk 1", "Size (GB) disk 1", "Type disk 1", `
            "Path disk 2", "Size (GB) disk 2", "Type disk 2", `
            "Path disk 3", "Size (GB) disk 3", "Type disk 3", `
            "Path disk 4", "Size (GB) disk 4", "Type disk 4", `
            "Path disk 5", "Size (GB) disk 5", "Type disk 5", `
            "Path disk 6", "Size (GB) disk 6", "Type disk 6" 

        # inventory of VM
        $Data.Name = $VM.name
        $Data.State = $VM.state
        $Data.MemoryMB = $VM.MemoryStartup / 1024 /1024
        $Data.PathVM = $VM.Path
        $Data.CPUCount = $VM.ProcessorCount
        $Data.Version = $VM.Version

        # network data
        $Data.NetworkSwitch = $VM.NetworkAdapters.SwitchName
        $Data.NetworkStatus = $VM.NetworkAdapters.Status
        $Data.NetworkVLANID = $VM.NetworkAdapters.vlansetting.AccessVlanId
    
        $VHDS = ForEach ($VMId IN $VM.VMId) {
            Get-VHD -ComputerName $node -VMID $VMId -ErrorAction SilentlyContinue
        }

        # find all disk of VM
        $i = 1
        ForEach ($VHD In $VHDs) {
            $Data."Path disk $i" = $VHD.Path
            $Data."Size (GB) disk $i" = ($VHD.Size /1024 /1024 /1024)
            $Data."Type disk $i"= $VHD.VHDType
            $i++
        }
    
        # join data
        $Report +=  $Data
    }
}
Write-Verbose "Create report $attrReportFile ..."
$Report | ConvertTo-Csv -NoTypeInformation -Delimiter ';' | Out-File $attrReportFile
