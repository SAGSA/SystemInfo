try
{
    
    $Win32_DiskDrive | foreach {
        $Disk=$_
        if ($Credential)
        {
            $Partitions=Get-WmiObject -query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($Disk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" -ComputerName $Computername -Credential $Credential
        }
        else
        {
            $Partitions=Get-WmiObject -query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($Disk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition" -ComputerName $Computername
        }
        
        $Partitions | foreach {
            $Partition=$_
            if ($partition.Name -match ".+#(.+),.+#(.+)")
            {
                $DiskNumber=$Matches[1]
                $PartitionNumber=$Matches[2]
            }
            else
            {
                Write-Error "Unknown partition name $($partition.Name)" -ErrorAction Stop
            } 
            if ($partition.type -match "Installable File System")
            {
                $PartType="MBR:IFS"
            }
            else
            {
               $PartType=$partition.type -replace " "
            
            }
            $Psobject=New-Object -TypeName psobject      
            $Psobject | Add-Member -MemberType NoteProperty -Name Partition -Value  $PartitionNumber
            $Psobject | Add-Member -MemberType NoteProperty -Name Type -Value $PartType
            $Psobject | Add-Member -MemberType NoteProperty -Name Size -Value $Partition.size
            $Psobject | Add-Member -MemberType NoteProperty -Name BootPartition -Value $Partition.bootpartition
            $Psobject | Add-Member -MemberType NoteProperty -Name BooTable -Value $Partition.bootable
            $Psobject | Add-Member -MemberType NoteProperty -Name Disk -Value  $DiskNumber
            $Psobject | Add-Member -MemberType NoteProperty -Name HddModel -Value  $Disk.model
            $Psobject.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.Partitions")
            $Psobject
        }
    }
}
catch
{
    Write-Error $_
}

