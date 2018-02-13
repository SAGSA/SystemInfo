if ($wmiMonitorID.UserFriendlyName -ne $null)
{
	$dispname  = $null
	$dispname=([System.Text.Encoding]::ASCII.GetString($wmiMonitorID.UserFriendlyName)).Replace("$([char]0x0000)","")		
    $dispname
}
else
{
"NotSupported"
}