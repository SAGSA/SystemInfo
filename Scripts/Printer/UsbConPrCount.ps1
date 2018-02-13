$count=0
$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor
$dispPrinter | foreach {
    if (($_.portname -match "Usb") -and ($_.local -eq $True) -and ($_.workOffline -eq $false))
    {
        $Count++                                                   
    }
                                                                                                                
}

 $count