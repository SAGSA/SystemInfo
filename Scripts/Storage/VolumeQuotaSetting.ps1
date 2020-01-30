#$Win32_Quotasetting=Get-WmiObject -Class Win32_Quotasetting
#$win32_volume=Get-WmiObject -Class win32_volume
function GetLocalDriveLetter
{
    
    
    $win32_volume | foreach {
        $Volume=$_
        if ($_.driveletter -match "\w:" -and $_.filesystem -eq "ntfs" -and $_.drivetype -eq 3)
        {
            $volume
        } 
    } | Select-Object driveletter,FreeSpace
}

$QStateHash = @{
    0="Disabled"
    1 = "Tracked"
    2="Enforced"
        
}
$LocalDrive=GetLocalDriveLetter
$Win32_Quotasetting | foreach {
    
    if ($LocalDrive -match $($_.VolumePath -replace "\\",""))
    {
        $VolPath=$_.VolumePath -replace "\\",""
        $FreeSpace=($LocalDrive | Where-Object {$_.driveletter -eq $VolPath}).freespace
        $QState=$QStateHash[[int]$($_.state)]
        $Psobject=New-Object -TypeName psobject
        $Psobject.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.VolumeQuotaSetting")
        $Psobject | Add-Member -MemberType NoteProperty -Name  State -Value  $QState
        $Psobject | Add-Member -MemberType NoteProperty -Name VolumePath -Value $_.VolumePath
        $Psobject | Add-Member -MemberType NoteProperty -Name DefaultWarningLimit -Value $_.DefaultWarningLimit
        $Psobject | Add-Member -MemberType NoteProperty -Name DefaultLimit -Value $_.DefaultLimit
        $Psobject | Add-Member -MemberType NoteProperty -Name FreeSpace -Value $FreeSpace
        $Psobject
    }
    
}