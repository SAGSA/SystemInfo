try
{
    $Uptime=$Win32_OperatingSystem.ConvertToDateTime($Win32_OperatingSystem.LocalDateTime) –$Win32_OperatingSystem.ConvertToDateTime($Win32_OperatingSystem.LastBootUpTime)
    $Uptime
    #"$($Uptime.days)"+":"+"$($Uptime.hours)"+":"+"$($Uptime.minutes)"+":"+"$($Uptime.seconds)"
}
catch
{
    Write-Error $_
}
