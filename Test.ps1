
function Get-SystemInfo1
{
[CmdletBinding()]
    param(
            [parameter(ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,Position=0)]
            [Alias('CN','Computername','DnsHostname')]
            [string[]]$Name="127.0.0.1",          
            [string]$RegistryKey,
            [string]$RegistryValue,
            [ValidateSet("GetStringValue","GetBinaryValue","GetDWORDValue")]
            [string]$RegistryValueType,
            $Credential,
            [Alias("ThrottleLimit")]
            [ValidateRange(1,1000)]
            [int]$MaxJob=254,
            [Alias("Timeout")]
            [ValidateRange(1,6000)]
            [int]$JobTimeOut=120,
            [switch]$AppendToResult,
            [switch]$ShowStatistics,
            [ValidateSet("*","HDDSmart","Test")] 
            [array]$Properties
            
            )
begin
{
#Config
#################################################################################################################################
#Default Information (information output when executed Get-SystemInfo without parameters)
$DefaultInfoConfig="OsCaption"

#FunctionConfig
$FunctionConfig=@{
OsVersion=          '-Class Win32_OperatingSystem -Property Version'
HDDSmart=           '-Class MSStorageDriver_FailurePredictStatus,MSStorageDriver_FailurePredictData,Win32_DiskDrive -ScriptBlock $SbHddSmart'
Test=               '-Link HDDSmart -Property SmartStatus'
}

$ManualNamespace=@{
wmiMonitorID='-Namespace Root\wmi'
MSStorageDriver_FailurePredictStatus='-Namespace Root\wmi'
MSStorageDriver_FailurePredictData='-Namespace Root\wmi'
StdRegProv='-Namespace ROOT\default -Query SELECT * FROM meta_class WHERE __class="StdRegProv"'
}

#End FunctionConfig
#################################################################################################################################
#Config Switch Param
$SwitchConfig=@{
OSInfo="OsVersion"
}

#Exclude switch Param
$ExcludeParam="Verbose","AppendToResult","Debug","ShowStatistics"
#End Config Switch Param

#################################################################################################################################
#End Config

#ScriptBlock
#################################################################################################################################
[scriptblock]$SbHddSmart=
{
	function ConvertTo-Hex ( $DEC ) {
		'{0:x2}' -f [int]$DEC
	}
	function ConvertTo-Dec ( $HEX ) {
		[Convert]::ToInt32( $HEX, 16 )
	}
	function Get-AttributeDescription ( $Value ) {
		switch ($Value) {
			'01' { 'Raw Read Error Rate' }
			'02' { 'Throughput Performance' }
			'03' { 'Spin-Up Time' }
			'04' { 'Number of Spin-Up Times (Start/Stop Count)' }
			'05' { 'Reallocated Sector Count' }
			'07' { 'Seek Error Rate' }
			'08' { 'Seek Time Performance' }
			'09' { 'Power On Hours Count (Power-on Time)' }
			'0a' { 'Spin Retry Count' }
			'0b' { 'Calibration Retry Count (Recalibration Retries)' }
			'0c' { 'Power Cycle Count' }
			'aa' { 'Available Reserved Space' }
			'ab' { 'Program Fail Count' }
			'ac' { 'Erase Fail Count' }
			'ae' { 'Unexpected power loss count' }
			'b7' { 'SATA Downshift Error Count' }
			'b8' { 'End-to-End Error' }
			'bb' { 'Reported Uncorrected Sector Count (UNC Error)' }
			'bc' { 'Command Timeout' }
			'bd' { 'High Fly Writes' }
			'be' { 'Airflow Temperature' }
			'bf' { 'G-Sensor Shock Count (Mechanical Shock)' }
			'c0' { 'Power Off Retract Count (Emergency Retry Count)' }
			'c1' { 'Load/Unload Cycle Count' }
			'c2' { 'Temperature' }
			'c3' { 'Hardware ECC Recovered' }
			'c4' { 'Reallocated Event Count' }
			'c5' { 'Current Pending Sector Count' }
			'c6' { 'Offline Uncorrectable Sector Count (Uncorrectable Sector Count)' }
			'c7' { 'UltraDMA CRC Error Count' }
			'c8' { 'Write Error Rate (MultiZone Error Rate)' }
			'c9' { 'Soft Read Error Rate' }
			'cb' { 'Run Out Cancel' }
			'cа' { 'Data Address Mark Error' }
			'dc' { 'Disk Shift' }
			'e1' { 'Load/Unload Cycle Count' }
			'e2' { 'Load ''In''-time' }
			'e3' { 'Torque Amplification Count' }
			'e4' { 'Power-Off Retract Cycle' }
			'e8' { 'Available Reserved Space2' }
			'e9' { 'Media Wearout Indicator' }
			'f0' { 'Head Flying Hours' }
			'f1' { 'Total LBAs Written' }
			'f2' { 'Total LBAs Read' }
			'f9' { 'NAND Writes (1GiB)' }
			'fe' { 'Free Fall Protection' }
			default { $Value }
		}
	}

$PnpDev=@{}
$hdddev=$Win32_DiskDrive | Select-Object Model,InterfaceType,FirmwareRevision,PNPDeviceID
$hdddev | foreach {
    $PnpDev.Add($($_.pnpdeviceid -replace "\\","\\"),$_)
}

$PnpDev.Keys | foreach {
    $PnpDevid=$_
    $TmpFailData=$MSStorageDriver_FailurePredictData | Where-Object  {$_.InstanceName -Match $PnpDevid}
    $TmpFailStat=$MSStorageDriver_FailurePredictStatus | Where-Object  {$_.InstanceName -Match $PnpDevid}
    if ($TmpFailStat)
    {
        $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name  PredictFailure -Value $TmpFailStat.PredictFailure
    }
    else
    {
        $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name  PredictFailure -Value 'Not supported'
    }
    if ($TmpFailData)
    {
        $Disk=$TmpFailData
        $i = 0
        $Report = @()
        $pByte = $null
		        foreach ( $Byte in $Disk.VendorSpecific ) {
			        $i++
			        if (( $i - 3 ) % 12 -eq 0 ) 
                    {
				        if ( $Byte -eq 0) { break }
				        $Attribute = '{0:x2}' -f [int]$Byte
			        } 
                    else 
                    {
				        $post = ConvertTo-Hex $pByte
				        $pref = ConvertTo-Hex $Byte
				        $Value = ConvertTo-Dec "$pref$post"
				        if (( $i - 3 ) % 12 -eq 6 ) 
                        {
					        if ( $Attribute -eq '09' ) { [int]$Value = $Value / 24 }
					        #$Report += [PSCustomObject]@{ Name = $( Get-AttributeDescription $Attribute ); Value = $Value }
				            $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name $( Get-AttributeDescription $Attribute) -Value $Value
                        }
			        }
			        $pByte = $Byte
                }

        #$Report
        
    }
    else
    {
        $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Not supported' 
    }
    $HddSmart=$PnpDev[$PnpDevid]
    $WarningThreshold=@{
    "Temperature"=45,54
    "Reallocated Sector Count"=1,10
    }
    $CriticalThreshold=@{
    "Temperature"=55
    "Reallocated Sector Count"=11
    }
        $HddWarning=$False
        $HddCritical=$False
        $HddSmart | Get-Member | foreach {
            $Property=$_.name
            if ($WarningThreshold[$Property])
            {
                $MinWarningThreshold=$WarningThreshold[$Property][0]
                $MaxWarningThreshold=$WarningThreshold[$Property][1]
                    if ($HddSmart.$Property -le $MaxWarningThreshold -and $HddSmart.$Property -ge $MinWarningThreshold)
                    {
                        $HddWarning=$true
                    }
            }
            

            if ($CriticalThreshold[$Property])
            {
                $MinCriticalThreshold=$CriticalThreshold[$Property]
                    if($HddSmart.$Property -ge $MinCriticalThreshold)
                    {
                        $HddCritical=$true
                    } 
            }
              
            
        #End Foreach
        }
    if ($HddSmart.smartstatus -ne "Not supported")
    {
        if ($HddWarning)
        {
            $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Warning' 
        }
        elseif($HddCritical -or $HddSmart.PredictFailure)
        {
            $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Critical'   
        }
        else
        {
            $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Ok'   
        }
    }
$HddSmart
#End Foreach
}


}

#################################################################################################################################
#EndScriptBlock 
#Block Function
#Registry function

function RegGetValue
{
[CmdletBinding()]
param(
[parameter(Mandatory=$true)]
[string]$Key,
[parameter(Mandatory=$true)]
[string]$Value,
[parameter(Mandatory=$true)]
[ValidateSet("GetStringValue","GetBinaryValue","GetDWORDValue")]
[string]$GetValue
)
if ($stdregprov -eq $null)
{
    Write-Error "Variable StdRegProv Null"
}
$ResultProp=@{
"GetStringValue"="Svalue"
"GetBinaryValue"="Uvalue"
"GetDWORDValue"="UValue"
}
$ErrorCode=@{
"1"="Value doesn't exist"
"2"="Key doesn't exist"
"2147749893"="Wrong value type"
"5"="Access Denied"
"6"="Wrong Key String"
}
$hk=@{

"HKEY_CLASSES_ROOT"=2147483648
"HKEY_CURRENT_USER"=2147483649
"HKEY_LOCAL_MACHINE"=2147483650
"HKEY_USERS"=2147483651
"HKEY_CURRENT_CONFIG"=2147483653

}
if($Key -match "(.+?)\\(.+)")
{
    if ($hk.Keys -eq $matches[1])
    {
        $RootHive=$hk[$matches[1]]
        $KeyString=$matches[2]
        $StdRegProvResult=$StdRegProv | Invoke-WmiMethod -Name $GetValue -ArgumentList $RootHive,$KeyString,$Value
    }
    else
    {
        Write-Error "$($matches[1]) Does not belong to the set $($hk.Keys)" -ErrorAction Stop
    }
    if ($StdRegProvResult.returnvalue -ne 0)
    {
        if ($ErrorCode["$($StdRegProvResult.returnvalue)"] -ne $null)
        {
            $er=$ErrorCode["$($StdRegProvResult.returnvalue)"]
            Write-Error "$Er! Key $Key Value $Value "
        }
        else
        {
            $er=$StdRegProvResult.returnvalue
            Write-Error "$GetValue return $Er! Key $Key Value $Value "
        }
        
    }
    else
    {
        $StdRegProvResult.($ResultProp["$GetValue"])
    }
}
else
{
    Write-Error "$Key not valid"
}

}

function RegEnumKey
{
[CmdletBinding()]
param(
[parameter(Mandatory=$true)]
[string]$Key
)
$ErrorActionPreference="Stop"
if ($stdregprov -eq $null)
{
    Write-Error "Variable StdRegProv Null"
}
$ErrorCode=@{
"1"="Value doesn't exist"
"2"="Key doesn't exist"
"5"="Access Denied"
"6"="Wrong Key String"
}
$hk=@{

"HKEY_CLASSES_ROOT"=2147483648
"HKEY_CURRENT_USER"=2147483649
"HKEY_LOCAL_MACHINE"=2147483650
"HKEY_USERS"=2147483651
"HKEY_CURRENT_CONFIG"=2147483653
}
if($Key -match "(.+?)\\(.+)")
{
$StdRegProvResult=$StdRegProv.EnumKey($hk[$matches[1]],$matches[2])
    if ($StdRegProvResult.returnvalue -ne 0)
    {
        if ($ErrorCode["$($StdRegProvResult.returnvalue)"] -ne $null)
        {
            $er=$ErrorCode["$($StdRegProvResult.returnvalue)"]
        }
        else
        {
            $er=$StdRegProvResult.returnvalue
        }
    Write-Error "$Er key $Key"
        
    }
    else
    {
        $StdRegProvResult.snames
    }
}
else
{
    Write-Error "$Key not valid"
}

}
#End Registry function 

function StartRunspaceJob
{
    param(
    $WmiVariable,
    $ScriptBlock,
    $ComputerName,
    $Prop
    )
    $ParamList=@{}
    $WmiVariable | Get-Member -MemberType NoteProperty  | foreach {$ParamList.Add($_.name,$WmiVariable.($_.name))}
    if ($PropertyParams[$prop] | Where-Object {$_.keys -eq "RunspaceImportVariable"})
    {
    $AddParam=@()
    $AddParam+=($PropertyParams[$prop] | Where-Object {$_.keys -eq "RunspaceImportVariable"}).RunspaceImportVariable
    $AddParam | foreach {
        if ($_ -match "^\$")
        {
            $ParamList.Add($($_ -replace "\$",""),$(get-variable -name $($_ -replace "\$","") -ValueOnly))
        }
        else
        {
            Write-Error "RunspaceImportVariable Wrong param $_. Check FunctionConfig" -ErrorAction Stop
        }
    
    }

    }

    $PowerShell = [powershell]::Create()
    [void]$PowerShell.AddScript(
    $ScriptBlock
    )
    [void]$PowerShell.AddParameters($ParamList)
    $PowerShell.Runspacepool = $RunspacePool
    $State = $PowerShell.BeginInvoke()
    $temp = '' | Select PSJobTypeName,PowerShell,State,Location,StartTime,Property,Runspace
    $temp.PSJobTypeName="RunspaceJob"
    $temp.powershell=$PowerShell
    $temp.state=$State
    $temp.location=$Computername
    $temp.StartTime=get-date
    $temp.Property=$Prop
    $temp.runspace=$Runspace
    $temp
}

function GetWmi{
param(
$ComputerName,
$WmiParamArray
)
$Count=0
$WmiParamArray | foreach {
    $WmiParam=$_
    if ($Credential -ne $null)
    {
        $LocalComputer=$env:COMPUTERNAME,"Localhost","127.0.0.1"
            if (!($LocalComputer -eq $ComputerName))
            {
                if (!($WmiParam["Credential"]))
                {
                    $WmiParam.Add("Credential",$Credential)
                }
            
            }    
    }
    if ($jobs.count -ge $MaxJob)
    {
        do {
            $repeat=$true
            GetJob
            if ($Jobs.Count -lt $MaxJob)
            {
                $repeat=$false
            }
            else
            {
                Start-Sleep -Milliseconds 20
            }   
        }while($repeat)
    }
    $RemoveClass=$null
    if ($WmiParam['Query'])
    {
        $RemoveClass=$WmiParam['Class']
        $WmiParam.Remove("Class")
    }
    if ($WmiParam['class'])
    {
        Write-Verbose "$Computername Start Job Get-WmiObject -Class $($WmiParam['class']) -NameSpace $($WmiParam['NameSpace'])"
    }
    else
    {
        Write-Verbose "$Computername Start Job Get-WmiObject -Query $($WmiParam['Query']) -NameSpace $($WmiParam['NameSpace'])"
    }
    $TmpWmiJob=Get-WmiObject @WmiParam -computername $ComputerName -ErrorAction Stop -AsJob   
    if ($?)
    {
        $temp = '' | Select-Object PSJobTypeName,WmiJob,StartTime,Location,Class,Query
        $temp.PSJobTypeName="WmiJob"
        $temp.WmiJob=$TmpWmiJob
        $temp.StartTime=Get-Date
        $Temp.Location=$ComputerName
            if ($RemoveClass)
            {
                $Temp.Class=$RemoveClass
                $Temp.Query=$true
            }
            else
            {
                $Temp.Class=$WmiParam['Class']
                $Temp.Query=$False
            }
    
        [void]$Jobs.Add($temp) 
        }

    if ($WmiParam['Query'])
    {
        $WmiParam.Add("Class",$RemoveClass)
    }
    $Count++
    if ($Count -eq $WmiParamArray.count)
    {
        Write-Verbose "$ComputerName All Wmi request completed"
        [void]$GetWmicompletedForComputers.Add($ComputerName)   
    }

#End Foreach
}

}

function WrErr($Err,$Job)
{
try{

if ($Job -eq $null)
{
    Write-Error "$Computername Job variable null" -ErrorAction Stop
}
if($tmperr=$Global:ErrorResult | Where-Object {$_.computername -eq $Job.location})
{
    if ($tmperr.warning -ne $err.Exception.Message)
    {
        Write-Warning  "$($Job.location) $($err.Exception.Message)"
        $tmperr.warning=$tmperr.warning+","+$err.Exception.Message
    }
}
else
{
    Write-Warning  "$($Job.location) $($err.Exception.Message)"
    $ErTmp="" | select ComputerName,Warning,Error
    $ErTmp.ComputerName=$Job.location
    $ErTmp.Warning=$err.Exception.Message
    $ErTmp.Error=$err
    $Global:ErrorResult+=$ErTmp
}
if ($Job.PSJobTypeName -eq "RunspaceJob")
{
    $Job.powershell.dispose()
    $Job.State = $null
    $Job.powershell = $null
}
$RemoveJobs=$jobs | Where-Object {$_.location -eq $Job.location}
$RemoveJobs  | foreach {$Jobs.Remove($_)}
}catch{
$Jobs.Remove($Job)
}

}

function GetJob
{
try{

#Write-Verbose "getjob"
#Start-Sleep -Milliseconds 500
#Failed Job
$AllFailedWmiJobs=$Jobs | Where-Object  {$_.WmiJob.State -eq "Failed"}
if ($AllFailedWmiJobs -ne $null)
{
    $AllFailedWmiJobs | foreach {
        try{
        $Job=$_.WmiJob
        $TmpErRec=$Job | Receive-Job -ErrorAction Stop
        if ($TmpErRec -eq $null)
        {
            if ($VerbosePreference -eq "Continue")
            {
                Write-Warning "$($Job.location) $($_.Class) JobState Failed Get-WmiObject return Null Value"
            }
            
        }
        Remove-Job $Job
        $Jobs.Remove($_)
        } catch {
        WrErr -Err $_ -Job $Job
        }
    # End Foreach
    }
}

#Completed Job
$AllCompletedJobs=$Jobs | Where-Object {$_.WmiJob.State -eq "Completed"} 
#Completed Runspace Job
$AllRunspaceCompletedJob=$jobs | Where-Object {$_.state.isCompleted}
if ($AllRunspaceCompletedJob -ne $null)
{
    $AllRunspaceCompletedJob | foreach {
        $Job=$_
        $TmpRes=$_.powershell.EndInvoke($_.State)
        if($_.powershell.HadErrors -eq $true)
        {
            if ($TmpRes.count -eq 0)
            {
                Write-Error "Scriptblock HadErrors, use try{}catch{} in the ScriptBlock to find out the details" -ErrorAction Stop
            }
            elseif ($TmpRes[0].GetType().name -eq "ErrorRecord")
            {
                Write-Error $TmpRes[0] -ErrorAction Stop
            }
            else
            {
                Write-Error "Unknown Error" -ErrorAction Stop
            }
        }
        elseif($TmpRes[0] -ne $null)
        {
                if ($TmpRes[0].GetType().name -eq "ErrorRecord")
                {
                    Write-Error $TmpRes[0] -ErrorAction Stop
                }
            Write-Verbose "$($Job.location) RunspaceJob for Property $($Job.property) Completed"
            write-verbose "$($Job.location) Add to result $($Job.property)=[Scriptblock]$(($PropertyParams[$Job.property] | Where-Object {$_.Scriptblock}).ScriptBlock)"
            $HashtableResult[$Job.location].($Job.property)=$TmpRes
            $_.powershell.dispose()
            $_.State = $null
            $_.powershell = $null
            $Jobs.Remove($Job)
                
        }
        else
        {
            Write-Error "Scriptblock return empty value" -ErrorAction Stop
        }
    
    # End Foreach
    }
}
if($AllCompletedJobs -ne $null)
{
    $AllCompletedJobs | foreach {
        $Job=$_.WmiJob
        $Computername=$_.location
        $GetWmi=@()
        $GetWmi+=Receive-Job -Job $Job -ErrorAction Stop
        if ($GetWmi.Count -eq 0 -or $GetWmi[0] -eq $null)
        {
            if ($VerbosePreference -eq "Continue")
            {
                Write-Warning -Message "$Computername $($_.Class) Get-Wmiobject return empty value.."
            }
        }
        else
        {
                if ($_.Query)
                {
                    $GwmiClass=$_.Class
                }
                else
                {
                    $GwmiClass=$GetWmi[0].__CLASS
                }
                    
                if ($GetWmi.Count -eq 1)
                {
                    $GetWmi=$Getwmi[0]
                }
            Write-Verbose "$Computername Receive-Job $GwmiClass Completed"
            $HashtableWMi[$ComputerName].$GwmiClass=$GetWmi
        }
        
        Remove-Job $Job -Force
        $Jobs.Remove($_)
    
    # End Foreach
    }

}
#Create Result
$TmpGetWmicompletedForComputers=$GetWmicompletedForComputers.clone()
$TmpGetWmicompletedForComputers | foreach {
    $ComputerName=$_
    if (!($Jobs | Where-Object {$_.Location -eq $ComputerName}))
    {
        if (!($Global:ErrorResult | Where-Object {$_.computername -eq $ComputerName}))
        {
            #Create Variable
            $HashtableWMi[$computername] | Get-Member -MemberType NoteProperty | foreach {New-Variable -Name $_.Name -Value $HashtableWMi[$computername].$($_.Name)}
            
            $AllProperties | foreach{
                $Property=$_
                $Keys=$PropertyParams[$property] | foreach {$_.keys}
                $ParamProperty=($PropertyParams[$Property] | Where-Object {$_.Property}).Property
                $ParamScriptblock=($PropertyParams[$Property] | Where-Object {$_.Scriptblock}).ScriptBlock
                $Class=($PropertyParams[$Property] | Where-Object {$_.class}).class
                if ($Keys -eq "UseRunspace")
                {
                    if ($HashtableResult[$ComputerName].$Property -eq $null)
                    {
                        #Add param to Runspace scriptblock
                        $AddParam=@()
                        #Add all wmi variable
                        $HashtableWMi[$computername] | Get-Member -MemberType NoteProperty | foreach {$AddParam+=('$'+$_.name)}
                            if ($Keys -eq "RunspaceImportVariable")
                            {
                                #Add all RunspaceImportVariable
                                $AddParam+=($PropertyParams[$property] | Where-Object {$_.runspaceimportvariable}).runspaceimportvariable
                            }
                        Write-Verbose -Message "$ComputerName Edit ScriptBlock [ScriptBlock]$($ParamScriptblock)"
                        $ScriptBlockParam = $ExecutionContext.InvokeCommand.NewScriptBlock("param($($AddParam -Join ", "))`r`n"+$(get-variable -name $($ParamScriptblock -replace "\$","") -ValueOnly).ToString())
                        Write-Verbose "$ComputerName StartRunspaceJob for Property $Property"
                        StartRunspaceJob -WmiVariable $HashtableWMi[$computername] -ScriptBlock $ScriptBlockParam -ComputerName $ComputerName -Prop $Property | foreach {[void]$Jobs.Add($_);}
                        
                        #It is mandatory to use this delay otherwise there are run-time errors
                        Start-Sleep -Milliseconds 200
                        
                    }
                    
                }
                if ($HashtableResult[$ComputerName].$Property -eq $null)
                {
                        if ($ParamProperty)
                        {
                            Write-Verbose ("$ComputerName Add to result $Property=$"+"$Class.$ParamProperty")
                            $WmiVariables=Get-Variable -Name $Class -ValueOnly
                                if ($WmiVariables.count -gt 1)
                                {
                                    $ResultParamProperty=$WmiVariables | foreach {$_.$ParamProperty}
                                }
                                else
                                {
                                    $ResultParamProperty=$WmiVariables.$ParamProperty
                                }
                            $HashtableResult[$ComputerName].$Property=$ResultParamProperty
                        }
                        elseif ($ParamScriptblock -and !($Keys -eq "UseRunspace" ))
                        {
                            Write-Verbose "$ComputerName Add to result $Property= [Scriptblock]$($ParamScriptblock)"
                            try
                                {
                                $HashtableResult[$ComputerName].$Property=&$(get-variable -name $($ParamScriptblock -replace "\$","") -ValueOnly)
                                }
                            catch
                                {
                                Write-Error -Message "Check Scriptblock [ScriptBlock]$ParamScriptblock $($_.Exception.message) $($_.InvocationInfo.PositionMessage)" -ErrorAction stop
                                }
                        }
                        elseif (!($Keys -eq "UseRunspace" ))
                        {
                            Write-Verbose ("$ComputerName Add to result $Property=$"+"$Class")
                            $WmiVariables=Get-Variable -Name $Class -ValueOnly
                            $ResultParamProperty=$WmiVariables
                            $HashtableResult[$ComputerName].$Property=$ResultParamProperty
                        }
                    
                   
                }
                        
                #End Foreach
            }
    
            #Remove Variable
            $HashtableWMi[$computername] | Get-Member -MemberType NoteProperty | foreach {Remove-Variable -Name $_.name -Force}
                if (!($Jobs | Where-Object {$_.Location -eq $ComputerName}))
                {
                    Write-Verbose -Message "$ComputerName All Job Completed"
                    $Global:Result+=$HashtableResult[$ComputerName]
                        if ($UpdateFormatData)
                        {
                            CreateFormatPs1xml -ForObject $HashtableResult[$ComputerName] -ErrorAction Stop
                            Update-FormatData -PrependPath $($env:TEMP+"\SystemInfoAutoformat.ps1xml") -ErrorAction SilentlyContinue
                            Set-Variable -Name UpdateFormatData -Value $false -Scope 1 -Force
                        }
                    $HashtableResult[$ComputerName].psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.AutoFormatObject") 
                    $HashtableResult[$ComputerName]
                    $GetWmicompletedForComputers.remove($ComputerName)
                }
        }

        
        
    }
# End Foreach
}



#Timeout Job
$AllTimeOutJob=$Jobs | Where-Object {(New-TimeSpan -start $_.StartTime).TotalSeconds -gt $JobTimeOut}
if ($AllTimeOutJob -ne $null)
{
    $AllTimeOutJob | foreach {
        try
        {
            $Job=$_
            Write-Error -Message "Timeout expired" -ErrorAction Stop
        }
        catch
        {
            WrErr -Err $_ -Job $Job
        }

    }
}

}
catch
{
    WrErr -Err $_ -Job $Job
}

# End Function
}

function CreateFormatPs1xml
{
[CmdletBinding()]
param(
$ForObject
)
$ConvertToGb="MemoryTotal","MemoryMaxIns","MemoryFree","MemoryAvailable","VideoRam"
$FormatTableFor="PSCustomObject","ManagementObject"
[string]$XmlFormatList=''
$DollarUnder='$_'
$AllProperties | foreach{
    $Property=$_
    if ($Forobject.$Property.count -gt 1)
    {
        $ForObjectProperty=$Forobject.$Property[0]
    }
    else
    {
        $ForObjectProperty=$Forobject.$Property
    }
    if ($ForObjectProperty -eq $null)
    {
        $XmlFormatList+="
            <ListItem>
                <PropertyName>$Property</PropertyName>
            </ListItem>"
    }
    elseif ($FormatTableFor -eq ($ForObjectProperty).GetType().name)
    {
        $XmlFormatList+="
        <ListItem>
        <Label>$Property</Label>
            <ScriptBlock> 
                $DollarUnder.$Property | ft -autosize | out-string
            </ScriptBlock>
        </ListItem>"
    }
    elseif ($ConvertToGb -eq $Property)
    {
               
        $XmlFormatList+="<ListItem>
        <Label>$Property</Label>
            <ScriptBlock>
		    [string]('{0:N1}' -f ($DollarUnder.$property/1gb))+'Gb'
            </ScriptBlock>
        </ListItem>"
                    
    }
    else
    {
        $XmlFormatList+="
        <ListItem>
            <PropertyName>$Property</PropertyName>
        </ListItem>"
    }
# End Foreach
}

#$XmlFormatList
$XmlAutoFormat='<?xml version="1.0" encoding="utf-8" ?>'
$XmlAutoFormat+="
<Configuration>
    <ViewDefinitions>
    <View>
        <Name>Default</Name>
            <ViewSelectedBy>
                <TypeName>ModuleSystemInfo.Systeminfo.AutoFormatObject</TypeName>
            </ViewSelectedBy>
    <ListControl>
        <ListEntries>
            <ListEntry>
                <ListItems>
                <ListItem>
                    <PropertyName>ComputerName</PropertyName>
                </ListItem>
                $XmlFormatList
                </ListItems>
            </ListEntry>
        </ListEntries>
    </ListControl>
    </View>
    </ViewDefinitions>
</Configuration>"
Write-Verbose "Create ps1xml file $($env:TEMP+"\SystemInfoAutoformat.ps1xml")"
$XmlAutoFormat | Out-File -FilePath $($env:TEMP+"\SystemInfoAutoformat.ps1xml") -Force -ErrorAction Stop
#End Function
}

Function ParseParam
{
param(
[parameter(Mandatory=$true)]
[string]$ParamString,
[String]$Property
)
$PermitParams="Class","ScriptBlock","UseRunspace","RunspaceImportVariable","Property","Query","Namespace","Link"
$ArrayHashTableParam=@()
$ArrayParamString=(((($ParamString -replace "\s+"," ") -replace "\s+$","") -replace "^-"," -") -replace " -"," --") -split "\s-"
$ArrayParamString | foreach {
    $HashTableParam=@{}
    if ($_ -match "^-(.+?)\s(.+)$")
    {
        $ParseParam=$Matches[1]
        $ParseValue=$Matches[2]
            if ($ParseValue -match ",")
            {
                $ArrayParseValue=$ParseValue -split ","
                $ParseValue=$ArrayParseValue
            }
        $HashTableParam.Add($ParseParam,$ParseValue)
        $ArrayHashTableParam+=$HashTableParam
    
    }
    elseif ($_ -match "-(.+\S)")
    {
        $HashTableParam.Add($Matches[1],$null)        
        $ArrayHashTableParam+=$HashTableParam
    }
# End Foreach
}
$DifObj=$ArrayHashTableParam | foreach {$_.keys}
$CompareParam=Compare-Object -ReferenceObject $PermitParams -DifferenceObject $DifObj
if ($CompareParam | where-object {$_.sideindicator -eq "=>"})
{
    Write-Error "$Property Parameter -$(($CompareParam | Where-Object {$_.SideIndicator -eq "=>"}).inputobject) not allowed. Check FunctionConfig" -ErrorAction Stop
}
$ArrayHashTableParam

#End Function
}


#End Block Function
if ($PSBoundParameters['ShowStatistics'].ispresent)
{
    $BeginFunction=get-date
}
if ($PSBoundParameters['Credential'])
{
    if (!($Credential.gettype().name -eq "PSCredential"))
    {
        $Credential=Get-Credential $Credential
    }    
}
#Clear Old Job
Write-Verbose "Clear old Job"
Get-Job | where-object {$_.PSJobTypeName -eq "wmijob"} | Remove-Job -Force
#Check registry param
try
{
    if ($PSBoundParameters["RegistryKey"] -ne $null -or $PSBoundParameters["RegistryValue"] -ne $null -or $PSBoundParameters["RegistryValueType"] -ne $null)
    {
        if ($PSBoundParameters["RegistryKey"] -eq $null)   
        {
            $RegistryKey=Read-Host -Prompt "RegistryKey"
        }
        if ($PSBoundParameters["RegistryValue"] -eq $null)
        {
            $RegistryValue=Read-Host -Prompt "RegistryValue"
        }
        if ($PSBoundParameters["RegistryValueType"] -eq $null)
        {
            $RegistryValueType=Read-Host -Prompt "RegistryValueType"
        }
    
    $Properties+="RegistryValue"
    }

}
catch
{
    Write-Error "$_" -ErrorAction Stop
} 

#Collection all Properties
$AllPropertiesSwitch=@()
$AllPropertiesSwitch+=$PSBoundParameters.Keys | foreach {
    if ($PSBoundParameters[$_].ispresent -and !($ExcludeParam -eq $_))
    {
        $SwitchConfig[$_]        
    }

}
if ($AllPropertiesSwitch[0] -eq $Null -and $Properties -eq $null)
{
    $AllPropertiesSwitch=$DefaultInfoConfig   
}
$AllProperties+=$AllPropertiesSwitch+$Properties
if ($AllProperties.GetType().name -ne "string")
{
    $AllProperties=0..$AllProperties.Count | foreach {if ($AllProperties[$_] -ne $null){$AllProperties[$_]}}
    $AllProperties = $AllProperties | Select-Object -Unique
}
if ($AllProperties -match "\*")
{
    Write-Verbose "Property: $($FunctionConfig.Keys)"
    $AllProperties=$FunctionConfig.Keys -ne "RegistryValue"
}
else
{
    Write-Verbose "Property: $AllProperties"
}


#Parse FunctionConfig
$PropertyParams=@{}
$AllProperties | foreach {
    $FunctionProperty=$_
    $ArrayHashTableParam=@()
    if ($FunctionConfig[$FunctionProperty] -eq $Null)
    {
        Write-Error "Property $FunctionProperty not found in $('$FunctionConfig')" -ErrorAction Stop
    }
    $ArrayHashTableParam+=ParseParam -ParamString $FunctionConfig[$FunctionProperty] -Property $FunctionProperty
    if ($QueryTmp=$($ArrayHashTableParam | where-object {$_.Query}))
    {
            if ($QueryTmp.Query -match ".+from\s(.+?)\s")
            {
                $TmpClass="Query_"+$Matches[1]+"_"+$FunctionProperty
            }
            else
            {
                Write-Error "Wrong query $($QueryTmp.Query)! Check query param." -ErrorAction Stop
            }
            if ($TmpClassHash=$ArrayHashTableParam | where-object {$_.class})
            {
                $TmpArrayClass=@()
                $TmpArrayClass+=$TmpClassHash.Class
                $TmpArrayClass+=$TmpClass
                $TmpClassHash.Class=$TmpArrayClass
            }
            else
            {
                $TmpClassHash=@{
                Class="$TmpClass"
                }
                $ArrayHashTableParam+=$TmpClassHash
            }
    
    }
    if ($($ArrayHashTableParam | where-object {$_.class}) -ne $null)
    {
        $PropertyParams.Add($FunctionProperty,$ArrayHashTableParam)
    }
    else
    {
        Write-Error "$FunctionProperty missing -Сlass parameter. Check FunctionConfig" -ErrorAction Stop
    }
# End Foreach
}

#Check ScriptBlock param
$PropertyParams.keys | foreach {
    try
    {
        $UserProperty=$_
        $ParamHashTable=$PropertyParams[$UserProperty]
        $ParamScriptblock=$ParamHashTable | Where-Object {$_.keys -eq "Scriptblock"}
        if ($ParamScriptblock)
        {
            if ($ParamScriptblock.scriptblock -eq $null)
            {
                Write-Error "parameter -ScriptBlock is empty. Check FunctionConfig" -ErrorAction Stop
            }
            else
            {
                if ($ParamScriptblock.scriptblock -match "\$.+\S")
                {
                        if((get-variable -Name $($ParamScriptblock.scriptblock -replace "\$","") -ValueOnly -ErrorAction Stop).GetType().Name -ne "Scriptblock")
                        {
                            Write-Error "Wrong variable type $($ParamScriptblock.scriptblock). Check FunctionConfig, Use [Scriptblock]" -ErrorAction Stop
                        }
    
                }
                else
                {
                    Write-Error "Wrong -Scriptblock variable $($ParamScriptblock.scriptblock). Check FunctionConfig" -ErrorAction Stop
                }
            }
    

        }
    }
    catch
    {
        Write-Error "$UserProperty $($_.Exception.message)" -ErrorAction Stop
    }    
# End Foreach
}

    

#Create wmi param
$WmiParamArray=@()
$PropertyParams.Keys | foreach {$PropertyParams[$_]} | foreach {$_.class} | Sort-Object -Unique | foreach {
    $Query=$null
    $WmiParam=@{}
    $FakeClass=$_
    $Class=$_

    if ($Class -match "^Query_(.+)?_(.+)")
    {
        $Class=$Matches[1]
        $Query=($PropertyParams[$Matches[2]] | Where-Object {$_.query}).query
    }
    if ($ManualNamespace[$Class])
    {
        $ManualNamespaceParams=ParseParam -ParamString $($ManualNamespace[$Class])
        $ManualNamespaceParamNamespace= $ManualNamespaceParams | Where-Object {$_.namespace}
        $ManualNamespaceParamQuery= $ManualNamespaceParams | Where-Object {$_.Query}
            if ($ManualNamespaceParamNamespace)
            {
                $Namespace=$ManualNamespaceParamNamespace["Namespace"]
            }
            if ($ManualNamespaceParamQuery -and $query -eq $null)
            {
                $Query=$ManualNamespaceParamQuery["Query"]
            }   
    
    }
    else
    {
        try
        {
            if ((Get-WmiObject -query "SELECT * FROM meta_class WHERE __class = '$Class'").__NAMESPACE -eq "ROOT\cimv2")
            {
                $Namespace="ROOT\cimv2"
            }
            else
            {
                Write-Error 'Cannot retrieve Namespace use $ManualNamespace hashtable' -ErrorAction Stop
            } 
        }
        catch
        {
            Write-Error "Cannot retrieve Namespace for class $Class check Functionconfig or use hashtable $('$ManualNamespace') " -ErrorAction Stop
        }
    }
    $WmiParam.Add("Class",$FakeClass)
    $WmiParam.Add("Namespace",$Namespace)
    if ($Query)
    {
        $WmiParam.Add("Query",$Query)
        $ManualNamespaceParamQuery=$Null
    }
    if ($WmiParam.class -ne $Null -and $WmiParam.Namespace -ne $Null)
    {
        $WmiParamArray+=$WmiParam
    }
    else
    {
        Write-Error "Class or Namspace not found" -ErrorAction Stop
    }
#End Foreach
}

#$WmiParamArray
#$PropertyParams

$OpenRunspace=$false
if (($PropertyParams.keys | foreach {$PropertyParams[$_]} | foreach {$_.keys}) -eq "UseRunspace")
{
    $OpenRunspace=$true
}
    
#Import function to runspace
$RunspaceImportFunction="RegGetValue","RegEnumKey"
if ($OpenRunspace)
{
    Write-Verbose "Use Runspace"
    $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    Get-Command -CommandType Function -Name $RunspaceImportFunction | foreach {
        $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $_.name, $_.Definition
        $SessionState.Commands.Add($SessionStateFunction)
    }
        if ($?)
        {
            Write-Verbose "Runspace Commands Add Successfully"
        } 
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1,$MaxJob,$SessionState,$Host)
    $RunspacePool.Open()
}


#Remove old ps1xml file
if (Test-Path $($env:TEMP+"\SystemInfoAutoformat.ps1xml"))
{
    Write-Verbose "Remove ps1xml file $($env:TEMP+"\SystemInfoAutoformat.ps1xml")"
    Remove-Item -Path $($env:TEMP+"\SystemInfoAutoformat.ps1xml") -Force
}

$computers=@()
$jobs = New-Object System.Collections.ArrayList
$GetWmicompletedForComputers = New-Object System.Collections.ArrayList
$HashtableResult=@{}
$HashtableWMi=@{}
$HashtableRunspace=@()
$Global:ErrorResult=@()
$UpdateFormatData=$true

if ($PSBoundParameters["AppendToResult"].IsPresent)
{
    if (!(Get-Variable -Name Result -Scope Global))
    {
        $Global:Result=@()
    }
    elseif((Get-Variable -Name Result -Scope Global -ValueOnly).count -eq $null)
    {
        $OldRes=$Global:Result
        $Global:Result=@()
        $Global:Result+=$OldRes
    }
}
else
{
    $Global:Result=@()
}

$CountComputers=0
}
process
{
$computers=@()
if ($Name -ne $null)
{
    $computers+=$Name                
}

$computers| foreach {
    $CountComputers++

    $TmpObjectProp=@{
    ComputerName=$_
    }
    $TmpObjectWmiProp=@{}
    $AllProperties | foreach {
        $TmpObjectProp.add($_,$null)  
    }
    $WmiParamArray | foreach {
        $WmiParam=$_
        $TmpObjectWmiProp.Add($WmiParam["Class"],$null)
    }
    $TmpObject=New-Object psobject -Property $TmpObjectProp
    $TmpObjectWmi=New-Object psobject -Property $TmpObjectWmiProp
    #$TmpObject | Add-Member -NotePropertyName ComputerName -NotePropertyValue $_
    #$TmpObject.ComputerName=$_
    if (!($HashtableResult[$_]))
    {
        [void]$HashtableResult.Add($_,$TmpObject)
    }
    if (!($HashtableWMi[$_]))
    {
        [void]$HashtableWMi.Add($_,$TmpObjectWmi)
    }
    try{
    GetWmi -WmiParamArray $WmiParamArray -ComputerName $_
    }
    catch{
        Write-Error "$_ getwmi error"
    }   
#End Foreach
}


}
end
{
do {
    $repeat=$false
    GetJob
        if ($Jobs.Count -ne 0)
        {
            $repeat=$true
        }
}
while($repeat)

$Global:ErrorResult=$Global:ErrorResult | Sort-Object -Property Warning
if ($Global:ErrorResult -eq $null)
{
    $ErrResCount=0
}
elseif ($Global:ErrorResult.count -eq $null)
{
    $ErrResCount=1
}
else
{
    $ErrResCount=$Global:ErrorResult.count
}

$ResultCount=$Global:Result.count
if ($Global:Result.Count -eq 1)
{
    $Global:Result=$Global:Result | foreach {$_}
}
        
if ($RunspacePool -ne $null)
{
    $RunspacePool.close()
}
#Write-Verbose "Clear all failed wmi job"
#Get-Job | Where-Object {$_.State -eq "Failed"} | Remove-Job -Force
if ($PSBoundParameters['ShowStatistics'].ispresent)
{
    Write-Verbose  "Function running  $((New-TimeSpan -Start $BeginFunction).TotalSeconds) seconds" -Verbose
    Write-Verbose  "Total Computers   $CountComputers" -Verbose
    Write-Verbose  "Success           $ResultCount" -Verbose
    Write-Verbose  "Errors            $ErrResCount" -Verbose
}

#End Function
}




}
Get-SystemInfo1 -Properties HDDSmart