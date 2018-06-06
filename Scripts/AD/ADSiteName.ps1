try
{
    RegGetValue -Key HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters -Value DynamicSiteName -GetValue GetStringValue -ErrorAction Stop
}
catch
{
    Write-Error $_
}