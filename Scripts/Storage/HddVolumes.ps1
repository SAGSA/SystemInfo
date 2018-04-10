try
{
    $DrTypehash = @{
        2 = "Removable"
        3="Fixed"
        4="Network"
        5 = "Compact"
    }
    $ASSOCIATORSTable=@{}
    $Win32_LogicalDiskToPartition | foreach{
        if ($_.Dependent -match '.+=\"(.+:)\"')
        {
            $DDrive=$Matches[1]
        }
        if ($_.Antecedent -match '.+=\"(.+)\"')
        {
            $DiskIndex=$Matches[1] -replace " "
        }
        $ASSOCIATORSTable.add($DDrive,$DiskIndex)
    }
    $Win32_Volume | foreach {
        $Volume=$_
        $DiskIndexPartIndex=$null
        $Disk=$null
        $Partition=$null
        if ($Volume.DriveLetter)
        {
            $DiskIndexPartIndex=$ASSOCIATORSTable[$Volume.DriveLetter]
            if ($DiskIndexPartIndex -match ".+#(.+),.+#(.+)")
            {
                $Disk=$Matches[1]
                $Partition=$Matches[2]
            }
        }
        
        $DriveType=$DrTypehash[[int]$($Volume.DriveType)]
        if ($DriveType -eq $null)
        {
            $DriveType=$Volume.DriveType
        }
        $Psobject=New-Object -TypeName psobject      
        $Psobject | Add-Member -MemberType NoteProperty -Name Drive -Value  $Volume.DriveLetter
        $Psobject | Add-Member -MemberType NoteProperty -Name Label -Value $Volume.label
        $Psobject | Add-Member -MemberType NoteProperty -Name Size -Value $Volume.Capacity
        $Psobject | Add-Member -MemberType NoteProperty -Name FreeSpace -Value $Volume.FreeSpace
        $Psobject | Add-Member -MemberType NoteProperty -Name BootVolume -Value $Volume.BootVolume
        $Psobject | Add-Member -MemberType NoteProperty -Name FS -Value $Volume.FileSystem
        $Psobject | Add-Member -MemberType NoteProperty -Name PageFilePresent -Value $Volume.PageFilePresent
        $Psobject | Add-Member -MemberType NoteProperty -Name Antecedent -Value $DiskIndexPartIndex
        $Psobject | Add-Member -MemberType NoteProperty -Name Disk -Value $Disk
        $Psobject | Add-Member -MemberType NoteProperty -Name Partition -Value $Partition
        $Psobject | Add-Member -MemberType NoteProperty -Name Compressed -Value $Volume.Compressed
        $Psobject | Add-Member -MemberType NoteProperty -Name DriveType -Value $DriveType
        $Psobject.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.Volumes")
        $Psobject
    
    }
            
}
catch
{
    Write-Error $_
}