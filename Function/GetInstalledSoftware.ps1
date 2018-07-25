function GetInstalledSoftware
{
    [cmdletbinding()]
    param([string]$SoftwareName,[string]$MatchSoftwareName,[array]$MatchExcludeSoftware,[switch]$DisplayAdvInfo)
    try
    {  
        
        function GetSoftwareFromRegistry
        {
        param([string]$RootKey,[array]$SubKeys,[string]$MatchSoftwareName,[string]$SoftwareName,[string]$DisplayOSArch)
            function CreateSoftwareInfo
            {
                $Version =RegGetValue -key $ChildPath -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
                $Publisher=RegGetValue -key $ChildPath -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue
                $TmpObject= New-Object psobject
                $TmpObject | Add-Member -MemberType NoteProperty -Name AppName -Value $AppName
                $TmpObject | Add-Member -MemberType NoteProperty -Name Architecture -Value $DisplayOSArch
                $TmpObject | Add-Member -MemberType NoteProperty -Name Version -Value $Version
                if ($DisplayAdvInfo.IsPresent)
                {
                    $InstallLocation=RegGetValue -key $ChildPath -Value "InstallLocation" -GetValue GetStringValue -ErrorAction SilentlyContinue
                    $UninstallString=RegGetValue -key $ChildPath -Value "UninstallString" -GetValue GetStringValue -ErrorAction SilentlyContinue
                    $TmpObject | Add-Member -MemberType NoteProperty -Name InstallLocation -Value $InstallLocation
                    $TmpObject | Add-Member -MemberType NoteProperty -Name UninstallString -Value $UninstallString
                }
                
                $TmpObject | Add-Member -MemberType NoteProperty -Name Publisher -Value $Publisher
                $TmpObject  
            }
            $SubKeys | foreach {
                $ChildPath=Join-Path -Path $RootKey -ChildPath $_      
                $AppName=$null
                $AppName = RegGetValue -key $ChildPath -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
                if ($AppName -ne $null)
                {
                    if ($PSBoundParameters["MatchSoftwareName"] -ne $null)
                    {
                        if ($AppName -match $MatchSoftwareName)
                        {
                            CreateSoftwareInfo  
                        }
                        else
                        {
                            Write-Verbose "Skip $AppName"
                        }      
                    }
                    elseif ($PSBoundParameters["SoftwareName"] -ne $null)
                    {
                        if ($AppName -eq $SoftwareName)
                        {
                            CreateSoftwareInfo  
                        }
                        else
                        {
                            Write-Verbose "Skip $AppName"
                        }         
                    }
                    else
                    {
                        CreateSoftwareInfo   
                    }
                }
                else
                {
                    Write-Verbose "$Computername $ChildPath Value DisplayName is Null"
                }
            }
        }
        $GetArch=RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "PROCESSOR_ARCHITECTURE" -GetValue GetStringValue -ErrorAction Stop
        If($GetArch -eq "AMD64")
        {            
            $OSArch='64-bit'
        }            
        Else
        {            
            $OSArch='32-bit'            
        }
        $AllSoftWare=@()
        if ($OSArch -eq "64-bit")
        {
            $RootUninstallKeyX64="HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"  
            [array]$SubKeysX64=RegEnumKey -key $RootUninstallKeyX64
            if ($PSBoundParameters["MatchSoftwareName"] -ne $null)
            {
                $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKeyX64 -SubKeys $SubKeysX64 -DisplayOSArch "32-bit" -MatchSoftwareName $MatchSoftwareName
            }
            elseif($PSBoundParameters["SoftwareName"] -ne $null)
            {
                $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKeyX64 -SubKeys $SubKeysX64 -DisplayOSArch "32-bit" -SoftwareName $SoftwareName
            }
            else
            {
                $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKeyX64 -SubKeys $SubKeysX64 -DisplayOSArch "32-bit"
            }
            
        }

        $RootUninstallKey="HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        [array]$SubKeys=RegEnumKey -key $RootUninstallKey
        
            if ($PSBoundParameters["MatchSoftwareName"] -ne $null)
            {
                $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKey -SubKeys $SubKeys -DisplayOSArch $OSArch -MatchSoftwareName $MatchSoftwareName
            }
            elseif($PSBoundParameters["SoftwareName"] -ne $null)
            {
                $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKey -SubKeys $SubKeys -DisplayOSArch $OSArch -SoftwareName $SoftwareName
            }
            else
            {
                $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKey -SubKeys $SubKeys -DisplayOSArch $OSArch
            }
        
    
        if ($AllSoftWare.count -ne 0)
        {
            $AllSoftWare | Sort-Object {$_.AppName} -Unique | foreach {
                $ReturnSoftware=$True
                $Software=$_
                if ($PSBoundParameters["MatchExcludeSoftware"] -ne $null)
                {
                    $MatchExcludeSoftware | foreach {
                        if ($Software.AppName -match "^$_")
                        {
                           $ReturnSoftware=$false
                        }
                    }
                } 
                if ($ReturnSoftware)
                {
                    $Software
                }
            }
        }
        else
        {
            Write-Error "not found"
        }
    }
    catch
    {
        Write-Error $_
    }
}