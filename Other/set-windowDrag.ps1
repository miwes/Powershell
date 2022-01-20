$CSharpSig = @'

[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]

public static extern bool SystemParametersInfo(

                 uint uiAction,

                 uint uiParam,

                 uint pvParam,

                 uint fWinIni);

'@
$SetWindowAPI = Add-Type -MemberDefinition $CSharpSig -Name WinAPICall -Namespace SystemParamInfo –PassThru
# disable Window drag
$SetWindowAPI::SystemParametersInfo(0x0025, 0, $null,0)