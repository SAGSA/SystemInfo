#$StdregProv=Get-WmiObject -Class StdregProv -List
try
{
    $RegistryServiceKey='HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\'
    function ComputeHash
    {
    [cmdletbinding()]
    param(
    $Data,
    $FilePath,
    [validateset("Md5","Sha1","Sha256")]
    [string]$HashAlgorithm="Sha256"    
    )
        $ServiceProv=[System.Security.Cryptography.HashAlgorithm]::Create($HashAlgorithm)

        if ($PSBoundParameters['Data'] -ne $null)
        {
            if ($Data.GetType() -eq [string])
            {
                $enc = [system.Text.Encoding]::UTF8    
                $Bytes=$enc.GetBytes($Data)
            }
            elseif($Data.GetType() -eq [string[]])
            {
                $Data=$Data | Out-String
                $enc = [system.Text.Encoding]::UTF8    
                $Bytes=$enc.GetBytes($Data)
            }
            else
            {
                $Bytes=$Data
            }
            $Hash=[System.BitConverter]::ToString($ServiceProv.ComputeHash($Bytes)) -replace "-",""
        }
        elseif ($PSBoundParameters['FilePath'] -ne $null)
        {
            if (Test-Path $FilePath)
            {
                $Hash=[System.BitConverter]::ToString($ServiceProv.ComputeHash([System.IO.File]::ReadAllBytes($FilePath))) -replace "-",""   
            }
            else
            {
                Write-Error "File $FilePath not exist" -ErrorAction Stop
            }
        }
        $Hash
    }
    function GetRuleHash
    {
    param(
    [string]$SysmonPath,
    [string]$Algorithm="sha1"
    )
    
        $Command=$Sysmonpath+" -c"
        [scriptblock]$SbRunspace={
            param($Command)
            Invoke-Expression $Command
        }
        $PowerShell = [powershell]::Create()
        [void]$PowerShell.AddScript($SbRunspace)
        $ParamList=@{Command=$Command}
        [void]$PowerShell.AddParameters($ParamList)
        $State = $PowerShell.BeginInvoke()
        do{
            $retry=$True
            if ($State.IsCompleted)
            {
                $SysmonOut=$PowerShell.EndInvoke($State) 
                $PowerShell.Dispose()
                $PowerShell=$null
                $State=$null
                $retry=$false
    
            }

        }while($retry)
        $ExcludeString="RuleConfiguration","Servicename","Drivername","SystemMonitor","Copyright","Sysinternals"
        #$SysmonOut=Invoke-Expression $Command -ErrorAction Stop
        [System.Collections.ArrayList]$SysmonOut=$SysmonOut | foreach {

            $($_ -replace " ","").Trim()
        }

        $ExcludeString | foreach {
               $Exclude=$_
               if($m=$SysmonOut -match $Exclude)
               {
                    $rindex=$SysmonOut.IndexOf("$m")
                    $SysmonOut.RemoveAt($rindex)
               } 
       
        }
        $Rul = New-Object System.Text.StringBuilder
        $SysmonOut | foreach {
            [void]$Rul.Append($_)
        }
        $str=$rul.ToString()
        if ($str.Length -le 80)
        {
            Write-Verbose "$ComputerName SysmonOut: $str RuleHash may be incorrect.." -Verbose
        }
        if (!([string]::IsNullOrEmpty($str)))
        {
            ComputeHash -Data $str -HashAlgorithm $Algorithm
        }
        else
        {
            Write-Error "Impossible to calculate rule hash. Config string is null or empty" -ErrorAction Stop
        }
    }
    function GetSysmon
    {
        foreach($ServiceName in $(RegEnumKey -Key $RegistryServiceKey)) 
        {
            $ServiceKey=Join-Path -Path $RegistryServiceKey -ChildPath "$ServiceName"
            try
            {
                $DriverName=RegGetValue -Key "$ServiceKey\Parameters" -Value DriverName -GetValue GetStringValue -ErrorAction Stop
                $DriverRegKey=Join-Path $RegistryServiceKey "$DriverName\Instances\Sysmon Instance"
        
                $Altitude=RegGetValue -Key $DriverRegKey -Value Altitude -GetValue GetStringValue -ErrorAction Stop
                $SysmonPath=RegGetValue -Key $ServiceKey -Value ImagePath -GetValue GetStringValue -ErrorAction Stop
        
                return @{SysmonName=$serviceName;SysmonPath=$SysmonPath;DriverName=$DriverName}
        
            }
            catch
            {
                Write-Verbose "Skip $ServiceKey"
            }
    
        }
        Write-Error "Sysmon Not Found" -ErrorAction Stop
    }
    $SysmonInfo=GetSysmon
    $SysmonFilePath="'"+($SysmonInfo['SysmonPath'] -replace "\\","\\")+"'"
    $SrvName=$SysmonInfo['SysmonName']
    $SrvPath=$SysmonInfo['SysmonPath']
    if ($Credential)
    {
        $SysmonDrFile=Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -filter "Name=$SysmonFilePath" -ComputerName $Computername -Credential $Credential -ErrorAction Stop
        $SysmonService=Get-WmiObject -Class win32_service -Filter "Name='$SrvName'" -ComputerName $computername -Credential $credential
        Write-Verbose "Service state $($SysmonService.State)"
    }
    else
    {
        $SysmonDrFile=Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -filter "Name=$SysmonFilePath" -ComputerName $Computername -ErrorAction Stop 
        $SysmonService=Get-WmiObject -Class win32_service -Filter "Name='$SrvName'" -ComputerName $computername
        Write-Verbose "Service state $($SysmonService.State)"
    }

    if ($SysmonService.State -eq "Running")
    {
        $SysmonStatus="OK"
    }
    else
    {
        $SysmonStatus="NotWorking"    
    }

    $Res=New-Object psobject
    $Res | Add-Member -MemberType NoteProperty -Name ServiceName -value $SrvName
    $Res | Add-Member -MemberType NoteProperty -Name Path -value $SrvPath
    $Res | Add-Member -MemberType NoteProperty -Name Version -value $SysmonDrFile.Version
    
    if ($protocol -eq "WSMAN")
    {
        $ServiceState=$SysmonService.State 
        $DriverState=(get-service $SysmonInfo['DriverName']).status
        $RuleHash=GetRuleHash -SysmonPath $SrvPath  
        $Res | Add-Member -MemberType NoteProperty -Name RuleHash -value $RuleHash
        if ($ServiceState -eq "Running" -and $DriverState -eq "Running")
        {
            $SysmonStatus="OK"  
        }
        elseif($ServiceState -ne "Running")
        {
            $SysmonStatus="Service not working"
        }
        elseif($DriverState -ne "Running")
        {
            $SysmonStatus="Driver not working"
        }
    }
    $Res | Add-Member -MemberType NoteProperty -Name Status -value $SysmonStatus
    $Res
}
catch
{
    Write-Error $_
}
