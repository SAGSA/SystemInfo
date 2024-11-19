#$Win32_Battery=Get-WmiObject -Namespace "ROOT\cimv2" -ClassName "Win32_Battery"
#$BatteryCycleCount=Get-WmiObject -Namespace "ROOT\WMI" -ClassName "BatteryCycleCount"
#$BatteryFullChargedCapacity=Get-WmiObject -Namespace "ROOT\WMI" -ClassName "BatteryFullChargedCapacity"
#$BatteryStaticData=Get-WmiObject  -Namespace "ROOT\WMI" -ClassName "BatteryStaticData"
#$BatteryStatus=Get-WmiObject -Namespace "ROOT\WMI" -ClassName "BatteryStatus"
#$MSBatteryClass=Get-WmiObject  -Namespace "ROOT\WMI" -ClassName "MSBatteryClass"
#$SerialNumber = $BatteryStaticData.SerialNumber
#$DischargeRate = $BatteryStatus.DischargeRate
#$Discharging = $BatteryStatus.Discharging
#$Charging = $BatteryStatus.Charging
#$PowerOnline = $BatteryStatus.PowerOnline
#$Voltage = $BatteryStatus.Voltage
#$EstimatedRunTime = $Win32_Battery.EstimatedRunTime
$ManufactureName = $BatteryStaticData.ManufactureName
$CycleCount = $BatteryCycleCount.CycleCount
$DesignedCapacity = $BatteryStaticData.DesignedCapacity
$FullChargedCapacity = $BatteryFullChargedCapacity.FullChargedCapacity
$RemainingCapacity = $BatteryStatus.RemainingCapacity
$ManufactureName = $MSBatteryClass.ManufactureName | Where-Object {-not ($_ -eq $null)}

if($FullChargedCapacity -gt 0 -and $DesignedCapacity -gt 0){
    $Degraded=$([math]::Round(100 - (($FullChargedCapacity / $DesignedCapacity)*100)))
}

$Res=New-Object -TypeName psobject 
$Res | Add-Member -MemberType NoteProperty -Name Manufacture -Value $ManufactureName
$Res | Add-Member -MemberType NoteProperty -Name Designed -Value $DesignedCapacity
$Res | Add-Member -MemberType NoteProperty -Name FullCharged -Value $FullChargedCapacity
#$Res | Add-Member -MemberType NoteProperty -Name Remaining -Value $RemainingCapacity
$Res | Add-Member -MemberType NoteProperty -Name CycleCount -Value $CycleCount
$Res | Add-Member -MemberType NoteProperty -Name DegradedPercent -Value $Degraded
$Res


