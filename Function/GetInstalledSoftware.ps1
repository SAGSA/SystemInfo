#$stdregProv = Get-Wmiobject -list "StdRegProv" -namespace root\default
function GetInstalledSoftware
{
    [cmdletbinding()]
    param([string]$SoftwareName,[string]$MatchSoftwareName,[array]$MatchExcludeSoftware,[switch]$DisplayAdvInfo)
    try
    {  
        
        function GetSoftwareFromRegistry
        {
        param([string]$RootKey,[array]$SubKeys,[string]$MatchSoftwareName,[string]$SoftwareName,[string]$DisplayOSArch,[string]$Scope="AllUsers")
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
                    #$QuietUninstallString=RegGetValue -key $ChildPath -Value "QuietUninstallString" -GetValue GetStringValue -ErrorAction SilentlyContinue
                    $UninstallString=($UninstallString -replace '{',' "{') -replace '}','}"'
                    #$QuietUninstallString=($QuietUninstallString -replace '{',' "{') -replace '}','}"'
                    $TmpObject | Add-Member -MemberType NoteProperty -Name InstallLocation -Value $InstallLocation
                    $TmpObject | Add-Member -MemberType NoteProperty -Name UninstallString -Value $UninstallString
                    #$TmpObject | Add-Member -MemberType NoteProperty -Name QuietUninstallString -Value $QuietUninstallString
                }
                
                $TmpObject | Add-Member -MemberType NoteProperty -Name Publisher -Value $Publisher
                $TmpObject | Add-Member -MemberType NoteProperty -Name Scope -Value $Scope
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
        [string[]]$ExcludeSid="S-1-5-18","S-1-5-19","S-1-5-20" 
        $LoadedProfile=$Win32_UserProfile | Select-Object -Property * | Where-Object {!($ExcludeSid -eq $_.sid) -and $_.loaded} 
        if ($LoadedProfile -eq $null)
        {
            Write-Verbose "No uploaded user profile. Skip checking installed programs in the user profile"       
        }
        else
        {
            $LoadedProfile | foreach {
                $Sid=$_.sid
                $LastUseTime=$null
                $User=$null
                $ProfileDirectory=$null
                $LocalPath=$_.localpath
                $objSID = New-Object System.Security.Principal.SecurityIdentifier($Sid) 
                try
                {
                    $objUser = $objSID.Translate([System.Security.Principal.NTAccount])
                    $User=$objUser.Value
                    Write-Verbose "$Computername Translate sid $sid succesfully"
                }
                catch
                {
                    Write-Verbose "$Computername Unknown sid $sid"
                        if ($LocalAccount -eq $null)
                        {
                            if ($credential)
                            {
                                $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true" -Credential $credential
                            }
                            else
                            {
                                $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true"
                            }
                        }
                    $User=($LocalAccount | Where-Object {$_.sid -eq $Sid}).caption
                    if ($User -eq $null)
                    {
                        $User="Unknown"
                    }
                }
       
               $_ | Add-Member -MemberType NoteProperty -Name User -Value $User
               $_
            } | foreach {
                $UserRootUninstallKey="HKEY_USERS\$($_.sid)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                try{
                    [array]$SubKeys=RegEnumKey -key $UserRootUninstallKey -ErrorAction Stop
                    if ($PSBoundParameters["MatchSoftwareName"] -ne $null)
                    {
                        $AllSoftWare+=GetSoftwareFromRegistry -RootKey $UserRootUninstallKey -SubKeys $SubKeys -DisplayOSArch $OSArch -MatchSoftwareName $MatchSoftwareName -Scope $User
                    }
                    elseif($PSBoundParameters["SoftwareName"] -ne $null)
                    {
                        $AllSoftWare+=GetSoftwareFromRegistry -RootKey $UserRootUninstallKey -SubKeys $SubKeys -DisplayOSArch $OSArch -SoftwareName $SoftwareName -Scope $User
                    }
                    else
                    {
                        $AllSoftWare+=GetSoftwareFromRegistry -RootKey $UserRootUninstallKey -SubKeys $SubKeys -DisplayOSArch $OSArch -Scope $User
                    }
                }
                catch
                {
                    Write-Verbose "Skip checking installed programs in the user profile $_"
                }
                
        
            } 
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