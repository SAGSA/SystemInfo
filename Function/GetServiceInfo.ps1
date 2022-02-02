#$stdregProv = Get-Wmiobject -list "StdRegProv" -namespace root\default
function GetServiceInfo
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
                    $CommandLine =RegGetValue -key $ChildPath -Value "ImagePath" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                    $DisplayName=RegGetValue -key $ChildPath -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                    if ($CommandLine -match "(.+\.exe)")
                    {
                        $ImagePath=$Matches[1]
                    }
                    else
                    {
                        $ImagePath=$CommandLine
                    }
                    $TmpObject= New-Object psobject
                    $TmpObject | Add-Member -MemberType NoteProperty -Name DisplayName -Value $DisplayName
                    $TmpObject | Add-Member -MemberType NoteProperty -Name ImagePath -Value $ImagePath
                    $TmpObject | Add-Member -MemberType NoteProperty -Name CommandLine -Value  $CommandLine
                    $TmpObject  
                }
                $SubKeys | foreach {
                    $ChildPath=Join-Path -Path $RootKey -ChildPath $_      
                    $ImagePath=$null
                    $ImagePath =RegGetValue -key $ChildPath -Value "ImagePath" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                    if ($ImagePath -ne $null)
                    {
                        if ($PSBoundParameters["MatchBinPath"] -ne $null)
                        {
                            if ($ImagePath -match $MatchBinPath)
                            {
                                CreateServiceInfo
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