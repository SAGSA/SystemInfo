$dispNetAdap=$Win32_NetworkAdapterConfiguration | Select-Object -Property Description,MACAddress,IPAddress,DHCPServer,DefaultIPGateway,DNSServerSearchOrder
$dispNetAdap