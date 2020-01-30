#$Win32_ShadowStorage=Get-WmiObject -Class Win32_ShadowStorage
#$Win32_Volume=Get-WmiObject -Class Win32_Volume
if ($Win32_ShadowStorage)
{
    $Win32_Volume | foreach {
        $Volume=$_
        $VolDeviceID=$($volume.DeviceID -replace "\\","") -replace "\?",""
        $VolumeShadowStor=$Win32_ShadowStorage | Where-Object {$_.volume -match $VolDeviceID}
        if ($VolumeShadowStor)
        {
            $Psobj=New-Object -TypeName psobject
            $Psobj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.VolumeShadowStorage")
            $Psobj | Add-Member -MemberType NoteProperty -Name DriveLetter -Value $Volume.DriveLetter
            $Psobj | Add-Member -MemberType NoteProperty -Name UsedSpace -Value $VolumeShadowStor.UsedSpace
            $Psobj | Add-Member -MemberType NoteProperty -Name MaxSpace -Value $VolumeShadowStor.MaxSpace
            $Psobj
        }
    }
}
else
{
    $Psobj=New-Object -TypeName psobject
    $Psobj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.VolumeShadowStorage")
    $Psobj | Add-Member -MemberType NoteProperty -Name DriveLetter -Value $null
    $Psobj | Add-Member -MemberType NoteProperty -Name UsedSpace -Value 0
    $Psobj | Add-Member -MemberType NoteProperty -Name MaxSpace -Value 0
    $Psobj    
}