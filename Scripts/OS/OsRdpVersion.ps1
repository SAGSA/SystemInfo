#$Computername="Localhost"
#$Win32_OperatingSystem=Get-WmiObject -Class Win32_OperatingSystem
$OsVersion=$Win32_OperatingSystem.version
$SystemDir=$Win32_OperatingSystem.SystemDirectory
$File="$SystemDir\Mstsc.exe"
$filewmi=$file -replace "\\","\\"

if ($Credential)
{
    $FileInfo=Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$filewmi'" -ComputerName $Computername -ErrorAction Stop -Credential $Credential
}
else
{
    $FileInfo=Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$filewmi'" -ComputerName $Computername -ErrorAction Stop
}

$LastModified=$FileInfo.ConvertToDateTime($FileInfo.LastModified)
$PsObject=New-Object -TypeName psobject
#$PsObject | Add-Member -MemberType NoteProperty -Name Name -Value $FileInfo.Name
$PsObject | Add-Member -MemberType NoteProperty -Name Version -Value $FileInfo.Version
$PsObject | Add-Member -MemberType NoteProperty -Name LastModified -Value $LastModified
$PsObject