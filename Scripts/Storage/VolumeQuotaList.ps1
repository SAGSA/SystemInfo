#$Win32_DiskQuota=Get-WmiObject -Class Win32_DiskQuota
$Win32_DiskQuota | foreach {
    $Qrecord=$_
    if ($Qrecord.User -match '.+Domain=\"(.+)\",Name=\"(.+)\"')
    {
        $Domain=$Matches[1]
        $User=$Matches[2]
        $UserFullName=$Domain+"\"+$User
    }
    else
    {
        Write-Error "Incorrect user string"
    }
    if ($Qrecord.QuotaVolume -match '.+=\"(\w:)')
    {
        $DriveLetter=$Matches[1]+"\"
    }
    else
    {
        Write-Error "Incorrect QuotaVolume string"    
    }
    if ($Qrecord.DiskSpaceUsed -gt 0)
    {
        if ($Qrecord.DiskSpaceUsed -gt $Qrecord.Limit -and $Qrecord.Limit -ne 0)
        {
            $Status="Critical"
        }
        elseif($Qrecord.DiskSpaceUsed -le $Qrecord.Limit -and $Qrecord.DiskSpaceUsed -ge $Qrecord.WarningLimit )
        {
            $Status="Warning"
        }
        else
        {
            $Status="OK"
        }
    }
    else
    {
        $Status="OK"
    }
    
    
    $Psobject=New-Object -TypeName psobject
    $Psobject.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.VolumeQuotaList")
    $Psobject | Add-Member -MemberType NoteProperty -Name User -Value $UserFullName
    $Psobject | Add-Member -MemberType NoteProperty -Name DiskSpaceUsed -Value $Qrecord.DiskSpaceUsed
    $Psobject | Add-Member -MemberType NoteProperty -Name Limit -Value $Qrecord.Limit
    $Psobject | Add-Member -MemberType NoteProperty -Name WarningLimit -Value $Qrecord.WarningLimit
    $Psobject | Add-Member -MemberType NoteProperty -Name VolumePath -Value $DriveLetter
    $Psobject | Add-Member -MemberType NoteProperty -Name Status -Value $Status
    
    $Psobject
}