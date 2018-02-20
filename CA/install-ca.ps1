<# 
.SYNOPSIS 
    Install and configure CA
.DESCRIPTION 
.NOTES 
    Author     : Michal Weis
    Version    : 1.0
    20.02.2018  - release version 1.0
			
.LINK 
.EXAMPLE 
#> 

[CmdletBinding()]
Param
(
    [Parameter(Mandatory= $False,ValueFromPipeline= $True)] [string]$Firma = 'Firma'
    ,[Parameter(Mandatory= $False,ValueFromPipeline= $True)] [string]$URL = 'http://pki.firma.cz'
)

Set-StrictMode -Version 2.0

$CAPolicyFile = '[Version] 
Signature="$Windows NT$"
 
[BasicConstraintsExtension] 
PathLength=0 
Critical=Yes

[Certsrv_Server]  
LoadDefaultTemplates=0'

Try {
    Write-Verbose 'Install CA Role and management'
    Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeAllSubFeature -IncludeManagementTools -ErrorAction Stop
} Catch {
    Write-Warning "Error when add role - $Error[0]"
    Exit
}

Try {
    Write-Verbose 'Create CAPOLICY.INF file'
    $CAPolicyFile | Out-File C:\Windows\CAPOLICY.INF -Force
} Catch {
    Write-Warning "Error when created file CAPOLICY.INF - $Error[0]"
    Exit
}

Try {
    Write-Verbose 'Setting CA'
    Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -KeyLength 2048 -HashAlgorithmName SHA256 -ValidityPeriod Years -ValidityPeriodUnits 20 -CaCommonName "CA $Firma" -Force
    Write-Verbose 'Setting Audit CA'
    & Certutil -setreg CA\AuditFilter 127
} Catch {
    Write-Warning "Error when configurated CA - $Error[0]"
    Exit
}

Try {
    Write-Verbose 'Setting AIA'
    Add-CAAuthorityInformationAccess -URI "$URL/<ServerDNSName>_<CAName><CertificateName>.crt" -AddToCertificateAia -Force
} Catch {
    Write-Warning "Error when configurated AIA - $Error[0]"
}

Try {
    Write-Verbose 'Setting CRL'
    Add-CACrlDistributionPoint -URI "$URL/<caname><crlnamesuffix><deltacrlallowed>.crl"  -AddToCertificateCdp -AddToFreshestCrl -Force
    & Certutil -setreg CA\CRLPeriodUnits 7
    & Certutil -setreg CA\CRLPeriod "Days"
    & Certutil -setreg CA\CRLOverlapUnits "3"
    & Certutil -setreg CA\CRLOverlapPeriod "Days"
    & Certutil -setreg CA\CRLDeltaPeriodUnits 1
    & Certutil -setreg CA\CRLDeltaPeriod "Days"
} Catch {
    Write-Warning "Error when configurated CRL - $Error[0]"
}

Write-Verbose 'Restart CA service'
Restart-Service -Name CertSvc

Write-Verbose 'Waiting 10 seconds'
Start-Sleep -Seconds 10

Try {
    Write-Verbose 'Add template'
    Add-CATemplate -Name DomainController -Force
    Add-CATemplate -Name DomainControllerAuthentication -Force
} Catch {
    Write-Warning "Error when add CA template - $Error[0]"
}