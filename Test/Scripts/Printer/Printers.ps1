#$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor                                                          
$dispPrinter=$Win32_Printer | foreach {
    $Property=@{
    Name=$_.Name
    DriverName=$_.DriverName
    Local=$_.Local
    ShareName=$_.ShareName
    }
    $TmpObj=New-Object psobject -Property $Property
    $TmpObj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Printers.Printer")
    $TmpObj
}
$dispPrinter