if ($wmiMonitorID.SerialNumberID -ne $null)
{		
    $dispserial = $null
    $dispserial=([System.Text.Encoding]::ASCII.GetString($wmiMonitorID.SerialNumberID)).Replace("$([char]0x0000)","")			
    $dispserial		
}