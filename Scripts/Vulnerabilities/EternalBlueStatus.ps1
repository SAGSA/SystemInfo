try
{
$HotfixInstalled=$false
$Status="NotPatched"
$hotFixIDs = @(
        "KB3205409", 
        "KB3210720", 
        "KB3210721", 
        "KB3212646", 
        "KB3213986", 
        "KB4012212", 
        "KB4012213", 
        "KB4012214", 
        "KB4012215", 
        "KB4012216", 
        "KB4012217", 
        "KB4012218", 
        "KB4012220", 
        "KB4012598", 
        "KB4012606", 
        "KB4013198", 
        "KB4013389", 
        "KB4013429",
        "KB4015217", 
        "KB4015438", 
        "KB4015546", 
        "KB4015547", 
        "KB4015548", 
        "KB4015549",
        "KB4015550",
        "KB4015551",
        "KB4016635",
        "KB4019215",
        "KB4019216",
        "KB4019217",
        "KB4019264",
        "KB4019472"
    )
if ([version]$Win32_OperatingSystem.Version -ge [Version]"10.0.14393") 
{
    $Status="NotRequired"   
}
$appliedHotFixID=$Win32_QuickFixEngineering | Where-Object {$hotFixIDs -eq $_.HotFixID}
$smb1Protocol = RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Value "SMB1" -GetValue GetDWORDValue -ErrorAction SilentlyContinue 
if ($smb1Protocol -eq 0) 
{
    $smb1ProtocolDisabled = $True
} 
else 
{
    $smb1ProtocolDisabled = $false
}

if ($appliedHotFixID)
{
    $HotfixInstalled=$true
    $Status="Patched"
}

$PsObject=New-Object -TypeName psobject

$PsObject | Add-Member -MemberType NoteProperty -Name HotfixInstalled -Value $HotfixInstalled
$PsObject | Add-Member -MemberType NoteProperty -Name Smb1ProtocolDisabled -Value $smb1ProtocolDisabled
$PsObject | Add-Member -MemberType NoteProperty -Name Status -Value $Status
$PsObject
}
catch
{
    $_
}


