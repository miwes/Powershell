@echo off 
SET SMTP=mail.firma.cz
SET FROM=ca@firma.cz
SET TO=pki@firma.cz

certutil -setreg exit\smtp\SMTPServer "%SMTP%"
certutil -setreg exit\smtp\SMTPAuthenticate 0 

:Setup_CA_For_Exit_Module 
REM certutil -setsmtpinfo -p "<Account>" Administrator 
certutil -setreg exit\smtp\eventfilter +EXITEVENT_CRLISSUED 
certutil -setreg exit\smtp\eventfilter +EXITEVENT_CERTDENIED 
certutil -setreg exit\smtp\eventfilter +EXITEVENT_CERTISSUED 
certutil -setreg exit\smtp\eventfilter +EXITEVENT_CERTPENDING 
certutil -setreg exit\smtp\eventfilter +EXITEVENT_CERTREVOKED 
certutil -setreg exit\smtp\eventfilter +EXITEVENT_SHUTDOWN 
certutil -setreg exit\smtp\eventfilter +EXITEVENT_STARTUP 

:CrlIssued 
certutil -setreg exit\smtp\CRLissued\To "%TO%" 
certutil -setreg exit\smtp\CRLissued\From "%FROM%" 
REM certutil -setreg exit\smtp\CRLissued\CC "<EmailAddress>" 
certutil -setreg exit\smtp\CRLissued\bodyformat "A new CRL has been issued" 
certutil -setreg exit\smtp\CRLissued\titleformat "A new CRL was issued by %%1" 
certutil -setreg exit\smtp\CRLissued\BodyArg "" 
certutil -setreg exit\smtp\CRLissued\TitleArg +"SanitizedCAName" 

:Denied 
certutil -setreg exit\smtp\Templates\Default\Denied\From "%FROM%" 
certutil -setreg exit\smtp\Templates\Default\Denied\CC "%TO%" 
certutil -setreg exit\smtp\Templates\Default\Denied\titleformat "Your certificate request was denied by %%1" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyArg "" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyFormat "" 
call Stop_Start_CA 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyArg +"Request.RequestID" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyArg +"Request.RequesterName" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyArg +"Request.SubmittedWhen" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyArg +"Request.DistinguishedName" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyArg +"Request.DispositionMessage" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyArg +"Request.StatusCode" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyFormat +"Your Request ID is: %%1" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyFormat +"The Requester Name is: %%2" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyFormat +"The Request Submission Date was: %%3" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyFormat +"Subject Name: %%4" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyFormat +"Request Disposition Message: %%5" 
certutil -setreg exit\smtp\Templates\Default\Denied\BodyFormat +"Request StatusCode: %%6" 
certutil -setreg exit\smtp\Templates\Default\Denied\TitleArg +"SanitizedCAName" 

:Certificate_Issued
certutil -setreg exit\smtp\Templates\Default\Issued\From "%FROM%" 
certutil -setreg exit\smtp\Templates\Default\Issued\CC "%TO%" 
certutil -setreg exit\smtp\Templates\Default\Issued\titleformat "Your certificate has been issued by %%1" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyArg +"RawCertificate" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat "" 
net stop certsvc 
call Stop_Start_CA 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Request ID: %%1" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"UPN: %%2" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Requester Name: %%3" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Serial Number: %%4" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Valid not before: %%5" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Valid not after: %%6" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Distinguished Name: %%7" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Certificate Template: %%8" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Certificate Hash: %%9" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Request Disposition Message: %%10" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Copy and paste the 
following in Notepad, save and install" 
certutil -setreg exit\smtp\Templates\Default\Issued\BodyFormat +"Binary Certificate: %%11" 

:Certificate_Pending 
certutil -setreg exit\smtp\Templates\Default\Pending\From "%FROM%" 
certutil -setreg exit\smtp\Templates\Default\Pending\CC "%TO%" 
certutil -setreg exit\smtp\Templates\Default\Pending\titleformat "Your certificate is pending on %%1" 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat "" 
call Stop_Start_CA 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat +"Request ID: %%1" 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat +"UPN: %%2" 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat +"Requester Name: %%3" 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat +"Time submitted: %%4" 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat +"Distinguished Name: %%5" 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat +"Certificate Template used: %%6" 
certutil -setreg exit\smtp\Templates\Default\Pending\BodyFormat +"Request Disposition Message: %%7" 

:Certificate_Revoked 
certutil -setreg exit\smtp\Templates\Default\Revoked\From "%FROM%" 
certutil -setreg exit\smtp\Templates\Default\Revoked\CC "%TO%" 
certutil -setreg exit\smtp\Templates\Default\Revoked\titleformat "Your certificate was revoked by %%1" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat "" 
call Stop_Start_CA 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Request ID: %%1" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Revoked when: %%2" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Effective: %%3" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Reason for being revoked: %%4" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"UPN: %%5" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Requester Name: %%6" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Serial Number: %%7" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Was not valid until: %%8" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Was not valid after: %%9" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Distinguished Name: %%10" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Certificate Template: %%11" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Certificate Hash: %%12" 
certutil -setreg exit\smtp\Templates\Default\Revoked\BodyFormat +"Request Status: %%13" 

:Certificate_Authority_Shutdown
certutil -setreg exit\smtp\Shutdown\To "%TO%" 
certutil -setreg exit\smtp\Shutdown\From "%FROM%" 
REM certutil -setreg exit\smtp\Shutdown\CC "<EmailAddress>" 

:Certificate_Authority_Startup
certutil -setreg exit\smtp\Startup\To "%TO%" 
certutil -setreg exit\smtp\Startup\From "%FROM%" 
REM certutil -setreg exit\smtp\Startup\CC "<EmailAddress>" 

:Stop_Start_CA 
net stop certsvc & net start certsvc 

:Exit 

