$Count=0
$Win32_NetworkAdapter | foreach {if ($_.physicaladapter){$count++}}
$count