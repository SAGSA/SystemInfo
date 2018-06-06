#$stdregProv = Get-Wmiobject -list "StdRegProv" -namespace root\default -computername localhost
try
{
    $RootUninstallKeyX64="HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $RootUninstallKey="HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $RootOfficeKeylKeyX64="HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Office"
    $RootOfficeKeylKey='HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office'
    $GetArch=RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "PROCESSOR_ARCHITECTURE" -GetValue GetStringValue -ErrorAction Stop
    $AllInstalledOffice=@()
    function GetOfficeInfo
    {
    param (
    [string]$RootOfficeKeylKey,
    [string]$DisplayArch,
    [string]$RootUninstallKey
    )

        RegEnumKey -key $RootOfficeKeylKey -ErrorAction SilentlyContinue | Where-Object {$_ -match "\d{2}\.\d"} | foreach {
            $ChildConfigPath=$_+"\Common\Config"
            $OfficeConfigPath=Join-Path -Path $RootOfficeKeylKey -ChildPath $ChildConfigPath  
            try
            {
                
                    if ($OfficeConfigPath -ne $null)
                    {
                    
                        RegEnumKey -key $OfficeConfigPath -ErrorAction SilentlyContinue | foreach {
                            $DisplayName=$null
                            $DisplayVersion=$null
                            $ChildUninstallPath=$_
                            $OfficeUninstallPath= Join-Path -path $RootUninstallKey -ChildPath $ChildUninstallPath
                            $DisplayName=RegGetValue -Key $OfficeUninstallPath -Value DisplayName -GetValue GetStringValue -ErrorAction SilentlyContinue
                            [version]$DisplayVersion=RegGetValue -Key $OfficeUninstallPath -Value DisplayVersion -GetValue GetStringValue -ErrorAction SilentlyContinue
                            if ($DisplayName -and $DisplayVersion)
                            {
                                $TmpObject=New-Object psobject
                                $TmpObject | Add-Member -MemberType NoteProperty -Name DisplayName -Value $DisplayName
                                $TmpObject | Add-Member -MemberType NoteProperty -Name Bitness -Value $DisplayArch
                                $TmpObject | Add-Member -MemberType NoteProperty -Name Version -Value $DisplayVersion
                                $TmpObject
                            }

                        }
                    }
                
            }
            catch
            {
                Write-Verbose "$ComputerName $_"
            }
        }
    }

    If($GetArch -eq "AMD64")
    {            
        $OSArch='64-bit'
    }            
    Else
    {            
        $OSArch='32-bit'            
    }

    if ($OSArch -eq "64-bit")
    {
       $AllInstalledOffice+=GetOfficeInfo -RootOfficeKeylKey $RootOfficeKeylKeyX64 -DisplayArch "32-bit" -RootUninstallKey $RootUninstallKeyX64
       $AllInstalledOffice+=GetOfficeInfo -RootOfficeKeylKey $RootOfficeKeylKey -DisplayArch "64-bit" -RootUninstallKey $RootUninstallKey   
    }
    else
    {
        $AllInstalledOffice+=GetOfficeInfo -RootOfficeKeylKey $RootOfficeKeylKey -DisplayArch "32-bit" -RootUninstallKey $RootUninstallKey    
    }
    if ($AllInstalledOffice.Count -eq 0)
    {
        "MsOffice not found"
    }
    else
    {
        $AllInstalledOffice
    }
    
}
catch
{
    Write-Error $_
}
