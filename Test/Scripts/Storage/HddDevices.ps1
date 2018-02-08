$DispInfo=GetHddSmart | foreach {
    $Property=@{
    Size=$_.Size
    InterfaceType=$_.InterfaceType
    Model=$_.Model
    SmartStatus=$_.SmartStatus
    }
    $TmpObj=New-Object psobject -Property $Property
    $TmpObj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.Devices")
    $TmpObj
}

$DispInfo