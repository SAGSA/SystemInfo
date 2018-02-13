$IsPrintServer=$false
$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor
$dispPrinter | foreach {
    if (($_.portname -match "Usb") -and ($_.local -eq $True) -and ($_.workOffline -eq $false))
    {                                                     
        if ($_.shared -eq $true)
        {
            $IsPrintServer=$True
        }
                                                            
    }
                                                                                                           
}

$IsPrintServer 