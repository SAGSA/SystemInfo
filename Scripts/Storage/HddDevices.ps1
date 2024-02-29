$DispInfo=GetHddSmart -OsVersion $($Win32_OperatingSystem.version)| foreach {
    $Property=@{
        Size=$_.Size
        InterfaceType=$_.InterfaceType
        Model=$_.Model
        Type=$_.Type
        DriveLetter=$_.DriveLetter
        IsSystemDisk=$_.IsSystemDisk
        SmartStatus=$_.SmartStatus
    }
    $TmpObj=New-Object psobject -Property $Property
    $TmpObj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.Devices")
    $TmpObj
}

$DispInfo | Sort-Object -Property IsSystemDisk -Descending