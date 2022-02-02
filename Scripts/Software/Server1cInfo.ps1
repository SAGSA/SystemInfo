#$stdregProv = Get-Wmiobject -list "StdRegProv" -namespace root\default
function GetServiceInfo
{
    [cmdletbinding()]
    param([array]$MatchBinPath)

    function GetServiceInfoFromRegistry
    {
        [cmdletbinding()]
        param([array]$MatchBinPath)
        try
        {
            function GetServiceFromRegistry
            {
                    param([string]$RootKey,[array]$SubKeys,[string]$MatchBinPath)
                    function CreateServiceInfo
                    {
                        param([string]$ServiceName)
                        $CommandLine =RegGetValue -key $ChildPath -Value "ImagePath" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                        $DisplayName=RegGetValue -key $ChildPath -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                        $ObjectName=RegGetValue -key $ChildPath -Value "ObjectName" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                        if ($CommandLine -match "(.+\.exe)")
                        {
                            $ImagePath=$Matches[1]
                            $ImagePath=$ImagePath -replace '"'
                        }
                        else
                        {
                            $ImagePath=$CommandLine
                        }
                        $TmpObject= New-Object psobject
                        $TmpObject | Add-Member -MemberType NoteProperty -Name DisplayName -Value $DisplayName
                        $TmpObject | Add-Member -MemberType NoteProperty -Name Name -Value $ServiceName
                        $TmpObject | Add-Member -MemberType NoteProperty -Name ImagePath -Value $ImagePath
                        $TmpObject | Add-Member -MemberType NoteProperty -Name CommandLine -Value  $CommandLine
                        $TmpObject | Add-Member -MemberType NoteProperty -Name RunningAs -Value  $ObjectName
                        $TmpObject  
                    }
                    $SubKeys | foreach {
                        $ChildPath=Join-Path -Path $RootKey -ChildPath $_      
                        $ServiceName=$_
                        $ImagePath=$null
                        $ImagePath =RegGetValue -key $ChildPath -Value "ImagePath" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                        if ($ImagePath -ne $null)
                        {
                            if ($PSBoundParameters["MatchBinPath"] -ne $null)
                            {
                                if ($ImagePath -match $MatchBinPath)
                                {
                                    CreateServiceInfo -ServiceName $ServiceName
                                }
                                else
                                {
                                    #Write-Verbose "Skip $ImagePath"
                                }      
                            }
                            else
                            {
                                CreateServiceInfo  
                            }
                        }
                        else
                        {
                            #Write-Verbose "$Computername $ChildPath Value ImagePath is Null"
                        }
                    }
            }
    
            $AllServices=@()
            $ServiceRootKey="HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services"
            [array]$SubKeys=RegEnumKey -key $ServiceRootKey
            if ($PSBoundParameters["MatchBinPath"] -ne $null)
            {
                $AllServices+=GetServiceFromRegistry -RootKey $ServiceRootKey -SubKeys $SubKeys  -MatchBinPath $MatchBinPath
            }
            else
            {
                $AllServices+=GetServiceFromRegistry -RootKey $ServiceRootKey -SubKeys $SubKeys
            }
            if ($AllServices.count -ne 0)
            {
                $AllServices
            }
            else
            {
                Write-Error "not found $MatchBinPath"
            }
        }
        catch
        {
            Write-Error $_
        }
    
    }
    [array]$ServicesInfoRg=GetServiceInfoFromRegistry -MatchBinPath $MatchBinPath -ErrorAction Stop
    $ServicesInfoRg | foreach {
        $ServiceInfoRg=$_
        [string]$WmiQuery="select * from win32_service where Name='"+$($ServiceInfoRg.name)+"'"
        if ($Credential -ne $null)
        {
            $ServiceInfo=Get-WmiObject -Query $WmiQuery -Credential $Credential -ComputerName $Computername    
        }
        else
        {
            $ServiceInfo=Get-WmiObject -Query $WmiQuery -ComputerName $Computername    
        }
        
        #$ServiceInfo=Get-Service -Name $($ServiceInfoRg.name) -ErrorAction Stop
        if ($serviceinfo -eq $null)
        {
            Write-Error "Get-Service return null" -ErrorAction Stop
        }
        
        $ServiceInfoRg | Add-Member -MemberType NoteProperty -Name State -Value $($ServiceInfo.State) 
        $ServiceInfoRg | Add-Member -MemberType NoteProperty -Name StartType -Value $($ServiceInfo.StartMode) 
        $ServiceInfoRg
    }
}
try
{
    GetServiceInfo -MatchBinPath "\\ragent.exe" -ErrorAction Stop
}
catch
{
    Write-Verbose "$Computername $_" -Verbose
}

