try
{
    $SystemDir=$Win32_OperatingSystem.SystemDirectory
    $File=$SystemDir+"\wuaueng.dll"
    $filewmi=$file -replace "\\","\\"
    if ($Credential)
    {
        $UpdateAgentVersion=(Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$filewmi'" -ComputerName $Computername -Credential $Credential -ErrorAction Stop).version
    }
    else
    {
        $UpdateAgentVersion=(Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$filewmi'" -ComputerName $Computername -ErrorAction Stop).version
    }
    [version]$UpdateAgentVersion
}
catch
{
    Write-Error $_
}
