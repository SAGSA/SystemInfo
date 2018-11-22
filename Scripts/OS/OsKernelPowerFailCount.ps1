[int]$SeeHours=24
#$Win32_LocalTime=Get-WmiObject -class Win32_LocalTime 
$currentDate= Get-Date -Year $Win32_LocalTime.Year -Month $Win32_LocalTime.Month -Day $Win32_LocalTime.Day -Hour $Win32_LocalTime.Hour -Minute $Win32_LocalTime.Minute -Second $Win32_LocalTime.Second
$date=$currentDate.AddHours(-$SeeHours)
[wmi]$WmiObject=''
$datewmi=$WmiObject.ConvertFromDateTime($date)
if ($Credential)
{
    [array]$ErrorLog=get-wmiobject -query "Select * From Win32_NTLogEvent Where LogFile = 'System' And TimeWritten > '$datewmi' And EventCode = 41" -Namespace root\cimv2 -ComputerName $ComputerName -Credential $Credential
}
else
{
    [array]$ErrorLog=get-wmiobject -query "Select * From Win32_NTLogEvent Where LogFile = 'System' And TimeWritten > '$datewmi' And EventCode = 41" -Namespace root\cimv2 -ComputerName $ComputerName
}
Write-Verbose "errors in $SeeHours hours"
[string]$Result=''
$ErrorLog | foreach {
    if ($_.TimeWritten)
    {
        $Date=$WmiObject.ConvertToDateTime($($_.TimeWritten))
        $Result+=$Date.ToString()+"; "
    }
   
}
if ($ErrorLog)
{
    Write-Verbose "ToString $($ErrorLog.count)"
    $ErrCount=($ErrorLog.Count).ToString()
    $ErrCount+" "+$Result
}
else
{
    return "0"
}
