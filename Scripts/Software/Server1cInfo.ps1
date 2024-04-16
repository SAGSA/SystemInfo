function Get-1cServer{
    [cmdletbinding()]
    param(
        [string]$Computername="localhost",
        $Credential,
        [switch]$ReturnAll    
    )
    
    function GetServiceInfo{
        [cmdletbinding()]
        param(
            [array]$MatchBinPath,
            [string]$ServiceName
        
        )

        function GetServiceInfoFromRegistry
        {
            [cmdletbinding()]
            param(
                [array]$MatchBinPath,
                [string]$ServiceName
            )
            try
            {
                function GetServiceFromRegistry
                {
                        param(
                            [string]$RootKey,
                            [array]$SubKeys,
                            [string]$MatchBinPath,
                            [switch]$SubKeysEqServiceName
                        )
                        function CreateServiceInfo{
                            param(
                                [string]$ServiceName
                            )
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
                                }elseif($PSBoundParameters['SubKeysEqServiceName'].IsPresent){
                                    CreateServiceInfo -ServiceName $ServiceName    
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
                if($PSBoundParameters["ServiceName"] -ne $null){
                    $AllServices+=GetServiceFromRegistry -RootKey $ServiceRootKey -SubKeys $ServiceName -SubKeysEqServiceName
                }
                else{
                    [array]$SubKeys=RegEnumKey -key $ServiceRootKey
                    if ($PSBoundParameters["MatchBinPath"] -ne $null){
                        $AllServices+=GetServiceFromRegistry -RootKey $ServiceRootKey -SubKeys $SubKeys  -MatchBinPath $MatchBinPath
                    }
                    else{
                        $AllServices+=GetServiceFromRegistry -RootKey $ServiceRootKey -SubKeys $SubKeys
                    }
                }

                if ($AllServices.count -ne 0){
                    $AllServices
                }
                else{
                    Write-Error "not found $MatchBinPath"
                }
            }
            catch
            {
                Write-Error $_
            }
    
        }
        if($PSBoundParameters["ServiceName"] -ne $null){
            [array]$ServicesInfoRg=GetServiceInfoFromRegistry -ServiceName $ServiceName -ErrorAction Stop    
        }else{
            [array]$ServicesInfoRg=GetServiceInfoFromRegistry -MatchBinPath $MatchBinPath -ErrorAction Stop
        }
        
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
    function Parse1cCommandline{
        [cmdletbinding()]
        param(
            [parameter(Mandatory=$true)]
            [string]$Commandline
        )
        try{
            $Coomandline=$CommandLine -replace " /"," -"
            [string[]]$CommandlineParams=$Coomandline.Split("-").Trim()
            $DebugingMode=$false
            if($CommandlineParams -eq "debug"){
                $DebugingMode=$true
            }
            $ServerParams=@{}
            $CommandlineParams | Where-Object {$_ -match "\s+" -and $_ -notmatch ".+ragent.exe$"} | foreach{
                $ParamStr=($_ -replace "\s+"," ").Trim()
                if($ParamStr -match "^(.+?)\s(.+)$"){
                    $ParamName=$Matches[1]
                    $ParamValue=$Matches[2]
                }
                if($ParamName -eq "d"){
                    $ParamValue=$ParamValue -replace "\\+","\"
                    $ParamValue=$ParamValue -replace '"'
                }
                $ServerParams.Add($ParamName,$ParamValue)   
            }
            $ServerParams.Add("Debug",$DebugingMode)
            $ServerParams
        }catch{
            Write-Error $_
        }
    
    }
    try{
        $TestAdmin = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        $IsAdmin=$TestAdmin.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
        if($stdregProv -eq $null){
            if($Credential -ne $null){
                $stdregProv = Get-Wmiobject -list "StdRegProv" -namespace root\default -ComputerName $Computername -Credential $Credential
            }else{
                $stdregProv = Get-Wmiobject -list "StdRegProv" -namespace root\default -ComputerName $Computername
            }
            
        }
        
        [string]$Service1cQuery="select * from win32_service where PathName like '%ragent.exe%'"
        if($Credential -ne $null){
            $1cServices=Get-WmiObject -Query $Service1cQuery -ComputerName $Computername -ErrorAction Stop -Credential $Credential
        }else{
            $1cServices=Get-WmiObject -Query $Service1cQuery -ComputerName $Computername -ErrorAction Stop
        }
        
        $AllServers=@()
        if($1cServices -ne $null){
            $1cServices | foreach{
                $AllServers+=GetServiceInfo -ServiceName $_.name -ErrorAction Stop    
            }
            
        }
        
        $AllServersObject=@()
        #$AllProcess=Get-WmiObject -Class win32_process
        $ShowWarning=$True
        $AllServers | foreach{
            $ServerObj=$_
            $ServerImagePath=$ServerObj.ImagePath
            $AgentParam=Parse1cCommandline -Commandline $ServerObj.CommandLine -ErrorAction Stop
            $AgentPort=$AgentParam["port"]
            $Regport=$AgentParam["regport"]
            $PortRange=$AgentParam["range"]
            $DebugFlagIsPresent=$AgentParam["Debug"]
            $ServerInfoPath=$AgentParam["d"]
            #$ServerInfoSize=(Get-ChildItem -Path $ServerInfoPath -Recurse | Measure-Object -Property Length -Sum).sum
            #$ServerImage=Get-Item -Path $ServerImagePath -ErrorAction Stop
            $ServerImagePathWmi=$ServerImagePath -replace "\\","\\"
            if ($Credential -ne $null){
                $FileInfo=Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$ServerImagePathWmi'" -ComputerName $Computername -ErrorAction Stop -Credential $Credential
            }
            else{
                $FileInfo=Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$ServerImagePathWmi'" -ComputerName $Computername -ErrorAction Stop
            }
            [version]$ServerVersion=$FileInfo.Version
            $RunningDebugMode=$null
            if($ServerObj.state -eq "Running"){
                $ImagePathWmi=$ServerImagePath -replace "\\","\\"
                $WmiQuery="select ExecutablePath,CommandLine from win32_process where ExecutablePath = '"+$ImagePathWmi+"'"
                if($Credential -ne $null){
                    $RunningAgentProcess=Get-WmiObject -Query $WmiQuery -ComputerName $Computername -Credential $Credential
                }else{
                    $RunningAgentProcess=Get-WmiObject -Query $WmiQuery -ComputerName $Computername
                }
                
                $ServerProcessWmi=$RunningAgentProcess | Where-Object {
                    $($($_.ExecutablePath -replace '"') -eq $($ServerObj.ImagePath -replace '"'))

                }
                if($ServerProcessWmi -eq $null){
                    if(-not $IsAdmin -and $ShowWarning){
                        Write-Verbose "$Computername :Administrator rights are required to determine the RuningInDebugMode" -Verbose
                        $ShowWarning=$false 
                    }  
                }else{
                    $ServerProcessWmi | foreach{
                        $ServerProcessPath=$_.ExecutablePath  
                        $ServerProcessCommandline=$_.CommandLine
                        $ServerProcessParam=Parse1cCommandline -Commandline $ServerProcessCommandline -ErrorAction Stop    
                        $ServerProcessAgentPort=$ServerProcessParam["Port"]
                        if($ServerProcessPath -eq $ServerImagePath -and $ServerProcessAgentPort -eq $AgentPort){
                            $RunningDebugMode=$ServerProcessParam["debug"]
                        }
                    
                    }
                }
                
            
            }
            $ServerObj | Add-Member -MemberType NoteProperty -Name AgentPort -Value $AgentPort
            $ServerObj | Add-Member -MemberType NoteProperty -Name RegPort -Value $Regport
            $ServerObj | Add-Member -MemberType NoteProperty -Name PortRange -Value $PortRange
            $ServerObj | Add-Member -MemberType NoteProperty -Name DebugFlagIsPresent -Value $DebugFlagIsPresent
            $ServerObj | Add-Member -MemberType NoteProperty -Name RunningInDebugMode -Value $RunningDebugMode
            $ServerObj | Add-Member -MemberType NoteProperty -Name ServerConfigPath -Value $ServerInfoPath
            #$ServerObj | Add-Member -MemberType NoteProperty -Name ServerInfoSize -Value $ServerInfoSize
            $ServerObj | Add-Member -MemberType NoteProperty -Name ServerVersion -Value $ServerVersion
            
            $AllServersObject+=$ServerObj

        }
        if($PSBoundParameters["ReturnAll"].IsPresent){
            $OutResult=$AllServersObject   
        }else{
            $OutResult=$AllServersObject | Where-Object {$_.state -eq "Running"}   
        }
        $OutResult | Select-Object -Property DisplayName,Name,ImagePath,ServerConfigPath,StartType,State,AgentPort,RegPort,PortRange,DebugFlagIsPresent,RunningInDebugMode,ServerVersion
    }
    catch{
        Write-Error "$Computername $_"
    }

}
try{
    if($Credential -ne $Null){
        Get-1cServer -Computername $Computername -ReturnAll -ErrorAction Stop -Credential $Credential
    }else{
        Get-1cServer -Computername $Computername -ReturnAll -ErrorAction Stop
    }
    
}catch{
    Write-Verbose $_ -Verbose
}


