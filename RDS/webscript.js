strDomainUserName = objForm.elements["DomainUserName"].value;
if ( strDomainUserName.indexOf("\\") == -1 )
{
 strDomainUserName = "DOMENA\\" + strDomainUserName;
 objForm.elements("DomainUserName").value = strDomainUserName;
}
