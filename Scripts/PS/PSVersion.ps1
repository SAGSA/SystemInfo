#$stdregprov=Get-WmiObject -Class stdregprov -List
$PsEnumKeyKeys=RegEnumKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PowerShell"
$PsEnginekey="HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PowerShell\"+"$(($PsEnumKeyKeys | Sort-Object -Descending)[0])"+"\powershellengine"
$PsVersion=RegGetValue -Key $PsEnginekey -Value PowerShellVersion -GetValue GetStringValue
[version]$PsVersion