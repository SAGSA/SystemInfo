try
{
$HotfixEnabled=$False
$HotfixInstalled=$false
$kvaShadowRequired=$true
if ($Win32_Processor -is [array]) 
{
    $Win32_Processor = $Win32_Processor[0]
}
$manufacturer = $Win32_Processor.Manufacturer
if ($manufacturer -eq "AuthenticAMD") 
{
    $kvaShadowRequired = $false
}
elseif ($manufacturer -eq "GenuineIntel") 
{
    $regex = [regex]'Family (\d+) Model (\d+) Stepping (\d+)'
    $result = $regex.Match($cpu.Description)
            
    if ($result.Success) 
    {
        $family = [System.UInt32]$result.Groups[1].Value
        $model = [System.UInt32]$result.Groups[2].Value
        $stepping = [System.UInt32]$result.Groups[3].Value
                
        if (($family -eq 0x6) -and 
            (($model -eq 0x1c) -or
                ($model -eq 0x26) -or
                ($model -eq 0x27) -or
                ($model -eq 0x36) -or
                ($model -eq 0x35))) 
        {

            $kvaShadowRequired = $false
        }
    }
}
else 
{
    $kvaShadowRequired="Unsupported processor $manufacturer"
}


$AntivirusUpdatedKey=RegGetValue -key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\QualityCompat" -Value "cadca5fe-87d3-4b96-b7fb-a231484277cc" -GetValue GetDWORDValue -ErrorAction SilentlyContinue
if ($AntivirusUpdatedKey -eq 0)
{
    $AntivirusUpdatedKeyIsPresent=$true
}
else
{
    $AntivirusUpdatedKeyIsPresent=$False
}

$FeatureSettingsOverride=RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Value "FeatureSettingsOverride" -GetValue GetDWORDValue -ErrorAction SilentlyContinue 
$FeatureSettingsOverrideMask=RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Value "FeatureSettingsOverrideMask" -GetValue GetDWORDValue -ErrorAction SilentlyContinue   
if ($FeatureSettingsOverride -eq 3)
{
    $HotfixEnabled=$False
}
elseif($FeatureSettingsOverride -eq 0)
{
    
    $HotfixEnabled=$true
}

if ($Win32_OperatingSystem.ProductType -eq 1)
{
    if ($FeatureSettingsOverride -eq $null -and $FeatureSettingsOverrideMask -eq $null)
    {
        $HotfixEnabled=$true
    }
}
else
{
    if ($FeatureSettingsOverride -eq $null -and $FeatureSettingsOverrideMask -eq $null)
    {
        $HotfixEnabled=$False
    }
}

if ($Protocol -eq "Dcom")
{
Write-Warning "$Computername The information received with the help of Dcom protocol may be incorrect. Use the protocol Wsman to determine MeltdownSpectreStatus"
    
    $HotfixArray=@(
    "KB4056892",
    "KB4056891",
    "KB4056890",
    "KB4056888",
    "KB4056893",
    "KB4056894",
    "KB4056897"
    )

    $Kb=$Win32_QuickFixEngineering | Where-Object {$HotfixArray -eq $_.HotFixID}
    if ($Kb)
    {
        $HotfixInstalled=$true  

    }
    else
    {
        $HotfixInstalled=$False
    }

}
else
{
$NtQSIDefinition = @'
    [DllImport("ntdll.dll")]
    public static extern int NtQuerySystemInformation(uint systemInformationClass, IntPtr systemInformation, uint systemInformationLength, IntPtr returnLength);
'@
    $ntdll = Add-Type -MemberDefinition $NtQSIDefinition -Name 'ntdll' -Namespace 'Win32' -PassThru

    [System.IntPtr]$systemInformationPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    [System.IntPtr]$returnLengthPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)

    [System.UInt32]$systemInformationClass = 201
    [System.UInt32]$systemInformationLength = 4
    $retval = $ntdll::NtQuerySystemInformation($systemInformationClass, $systemInformationPtr, $systemInformationLength, $returnLengthPtr)
     
    if ($retval -eq 0)
    {
        [System.UInt32]$scfBpbEnabled = 0x01
        [System.UInt32]$scfBpbDisabledSystemPolicy = 0x02
        [System.UInt32]$flags = [System.UInt32][System.Runtime.InteropServices.Marshal]::ReadInt32($systemInformationPtr)
        $btiWindowsSupportEnabled = (($flags -band $scfBpbEnabled) -ne 0)
        $HotfixEnabled = (($flags -band $scfBpbDisabledSystemPolicy) -eq 0)
        $HotfixInstalled=$true
    }
    if (!$HotfixEnabled)
    {
       $HotfixEnabled=$False 
    }
    
}
$PsObject=New-Object -TypeName Psobject
$PsObject | Add-Member -MemberType NoteProperty -Name CpuIsVulnerable -Value $kvaShadowRequired
$PsObject | Add-Member -MemberType NoteProperty -Name FixInstalled -Value $HotfixInstalled
$PsObject | Add-Member -MemberType NoteProperty -Name FixEnabled -Value $HotfixEnabled
$PsObject | Add-Member -MemberType NoteProperty -Name AntivUpKeyIsPresent -Value $AntivirusUpdatedKeyIsPresent
if ($HotfixInstalled -and $HotfixEnabled)
{
    $status="Patched"
}
elseif($HotfixInstalled -and !$HotfixEnabled)
{
    $status="DisabledBySystemPolicy"
}
elseif(!$kvaShadowRequired)
{
    $status="NotRequired"
}
else
{
    $status="NotPatched"
}
$PsObject | Add-Member -MemberType NoteProperty -Name Status -Value $Status
$PsObject
}
catch
{
   Write-Error $_
}
