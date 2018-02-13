if ($wmiMonitorID.ProductCodeID -ne $null)
{		
	$dispproduct = $null
    $dispproduct=([System.Text.Encoding]::ASCII.GetString($wmiMonitorID.ProductCodeID)).Replace("$([char]0x0000)","")			
	$dispproduct		
}