#$ComputerName="LocalHost"
#$Win32_LocalTime=Get-WmiObject -Class Win32_LocalTime -Namespace root\cimv2 -ComputerName $ComputerName
[int]$SeeHours=24
$currentDate= Get-Date -Year $Win32_LocalTime.Year -Month $Win32_LocalTime.Month -Day $Win32_LocalTime.Day -Hour $Win32_LocalTime.Hour -Minute $Win32_LocalTime.Minute -Second $Win32_LocalTime.Second
$date=$currentDate.AddHours(-$SeeHours)
[wmi]$WmiObject=''
$datewmi=$WmiObject.ConvertFromDateTime($date)
if ($Credential)
{
    [array]$SrpLogEntries=get-wmiobject -query "Select * From Win32_NTLogEvent Where LogFile = 'Application' And TimeWritten > '$datewmi' And EventCode = 865" -Namespace root\cimv2 -Credential $Credential -ComputerName $ComputerName 
}
else
{
    [array]$SrpLogEntries=get-wmiobject -query "Select * From Win32_NTLogEvent Where LogFile = 'Application' And TimeWritten > '$datewmi' And EventCode = 865" -Namespace root\cimv2 -ComputerName $ComputerName 
}
if ($SrpLogEntries.Count -ne 0)
{
    $SrpLogEntries | foreach {
        $SrpLogEntry=$_
        $TmpObject=New-Object Psobject
        $TmpObject | Add-Member -MemberType NoteProperty -Name Path -Value $SrpLogEntry.InsertionStrings
        $TmpObject | Add-Member -MemberType NoteProperty -Name TimeGenerated -Value $WmiObject.ConvertToDateTime($($SrpLogEntry.TimeGenerated))
        $TmpObject
    }
}
else
{
    Write-Error "There are no SRP constraint records for the last $SeeHours hours"
}
