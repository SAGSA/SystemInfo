#$ComputerName="localhost"
#$Win32_OperatingSystem=Get-WmiObject -Class win32_OperatingSystem -ComputerName $ComputerName
$SystemDrive=$Win32_OperatingSystem.SystemDrive
$WmiQery='SELECT InstallDate from Cim_DataFile where path = "\\windows\\minidump\\" and Drive='+'"'+$SystemDrive+'" and Extension="dmp"'
if($Credential -ne $null){
    $DmpFilesDate=Get-WmiObject -Query $WmiQery -Credential $Credential -ComputerName $ComputerName
}else{
    $DmpFilesDate=Get-WmiObject -Query $WmiQery -ComputerName $ComputerName
}

[wmi]$WmiObject=''
$DumpsDate=@()
if($DmpFilesDate -ne $null){
    $DmpFilesDate | foreach {
        $CreateDate=$WmiObject.ConvertToDateTime($_.InstallDate)
        
        
        
        $DumpsDate+=$CreateDate
    }
}
$LastDumpCreate=$DumpsDate | Sort-Object -Descending | Select-Object -First 1
$DumpDate=New-Object -TypeName psobject
$DumpDate | Add-Member -MemberType NoteProperty -Name LastBSod -Value $LastDumpCreate
$DumpDate | Add-Member -MemberType NoteProperty -Name BSoDCount -Value $($DumpsDate.Count)
$DumpDate