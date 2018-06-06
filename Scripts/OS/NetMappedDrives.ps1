#$StdregProv=Get-WmiObject -Class Stdregprov -List
#$Win32_UserProfile= Get-WmiObject -Class Win32_UserProfile
try
{
    $AllLoadedProfile=GetUserProfile -OnlyLoaded -ErrorAction Stop
    $AllMappedDrivers=@()
    $AllLoadedProfile | foreach {
        $UserName=$_.user
        $NetDriveKey="HKEY_USERS\$($_.sid)\Network"
        $AllNetDrivesKey=RegEnumKey -Key $NetDriveKey -ErrorAction SilentlyContinue
        if ($AllNetDrivesKey -ne $null)
        {
            $AllNetDrivesKey | foreach {
                $DriverLetter=$_
                $DriverLetterRegKey=Join-Path -Path $NetDriveKey -ChildPath $DriverLetter  
                $RemotePath=RegGetValue -Key $DriverLetterRegKey -Value RemotePath -GetValue GetStringValue
                $TmpObject=New-Object psobject | Select-Object -Property User,DriveLetter,Target
                $TmpObject.User=$UserName
                $TmpObject.DriveLetter=$DriverLetter
                $TmpObject.Target=$RemotePath
                $AllMappedDrivers+=$TmpObject
            }   
        
        }
        else
        {
            $TmpObject=New-Object psobject | Select-Object -Property User,DriveLetter,Target 
            $TmpObject.User=$UserName
            $TmpObject.DriveLetter=$null
            $TmpObject.Target=$null   
            $AllMappedDrivers+=$TmpObject
        }
    
    }

$AllMappedDrivers      
}
catch
{
    Write-Error $_
}
