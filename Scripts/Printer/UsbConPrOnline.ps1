$ObjUsbConnectPrinters=@()
$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor
$dispPrinter | foreach {
    if (($_.portname -match "Usb") -and ($_.local -eq $True) -and ($_.workOffline -eq $false))
    {
        $ObjUsbConnectPrinter=New-Object psobject
        $ObjUsbConnectPrinter | Add-Member -NotePropertyName PrinterName -NotePropertyValue $_.name
        $ObjUsbConnectPrinter | Add-Member -NotePropertyName DriverName -NotePropertyValue $_.DriverName
        $ObjUsbConnectPrinters+=$ObjUsbConnectPrinter
    }
                                                          

}

$ObjUsbConnectPrinters
                    