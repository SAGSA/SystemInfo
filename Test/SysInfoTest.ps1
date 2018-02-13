function Get-SystemInfotest
{
[CmdletBinding()]
    param(
            [parameter(ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,Position=0)]
            [Alias('CN','Computername','DnsHostname')]
            [string[]]$Name=$Env:COMPUTERNAME,          
            [switch]$OsInfo,
            [switch]$Cpu,
            [switch]$Motherboard,
            [switch]$Memory,
            [switch]$HDD,
            [switch]$Video,
            [switch]$Monitor,
            [switch]$NetworkAdapter,
            [switch]$PrinterInfo,
            [switch]$UsbDevices,
            [switch]$SoftwareList,
            $Credential,
            [ValidateSet("Dcom","Wsman")]
            $Protocol="Dcom",
            [Alias("ThrottleLimit")]
            $ProcessFor=50,
            [ValidateRange(1,1000)]
            [int]$MaxWmiJob=20,
            [Alias("Timeout")]
            [ValidateRange(1,6000)]
            [int]$JobTimeOut=60,
            [switch]$AppendToResult,  
            [ValidateSet("*","OsVersion","OSArchitecture","OsCaption","OsInstallDate","OsUpTime","OsLoggedInUser","OsProductKey","MemoryTotal","MemoryFree","MemoryModules","MemoryModInsCount",
            "MemoryMaxIns","MemorySlots","ECCType","MemoryAvailable","Motherboard","MotherboardModel","DeviceModel","Cdrom","CdromMediatype","HddDevices","HddDevCount","HDDSmart",
            "HddSmartStatus","VideoModel","VideoRam","VideoProcessor","CPUName","CPUSocket","MaxClockSpeed","CPUCores","CPULogicalCore","MonitorManuf",
            "MonitorPCode","MonitorSN","MonitorName","MonitorYear","NetPhysAdapCount","NetworkAdapters","Printers","IsPrintServer","UsbConPrOnline","UsbDevices","CPULoad","SoftwareList","RegistryValue","OsAdministrators","OsActivationStatus")] 
            [string[]]$Properties
            
            )
begin
{
$TestAdmin = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin=$TestAdmin.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
$CurrentExecutionPolicy=Get-ExecutionPolicy
$ExecutionPolicyChanged=$false
if (!($RequiredExecutionPolicy -eq $CurrentExecutionPolicy))
{
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -Confirm:$false 
        if ($?)
        {
            $ExecutionPolicyChanged=$true
        }
        else
        {
            Write-Error "Formatting objects does not work. Run the command Set-ExecutionPolicy -ExecutionPolicy RemoteSigned and retry now" -ErrorAction Stop
        }    
}
#LoadFunctions
#####################################################################################################
$FunctionFolderName="Function"
$LoadScripts=@(
"Config\functionconfig.ps1",
"$FunctionFolderName\ParseParam.ps1",
"$FunctionFolderName\CreateResult.ps1",
"$FunctionFolderName\FormatObject.ps1",
"$FunctionFolderName\GetHddSmart.ps1",
"$FunctionFolderName\wmi.ps1",
"$FunctionFolderName\Registry.ps1",
"$FunctionFolderName\CreateErrorObject.ps1",
"$FunctionFolderName\PsJob.ps1",
"$FunctionFolderName\RunspaceJob.ps1"
)


$LoadScripts | foreach {
    .(Join-Path -Path $PSScriptRoot -ChildPath $_)
    if(!$?)
    {
        break
    }
}



$BeginFunction=get-date
#####################################################################################################


if ($PSBoundParameters['Credential'])
{
    if (!($Credential.gettype().name -eq "PSCredential"))
    {
        $Credential=Get-Credential $Credential
    }    
}
#Clear Old Job
Write-Verbose "Clear old Job"
Get-Job | Where-Object {$_.state -ne "Running"} | Remove-Job -Force

#Collection all Properties
#$AllPropertiesSwitch=@()
[string[]]$AllPropertiesSwitch+=$PSCmdlet.MyInvocation.BoundParameters.keys | foreach {
    if ($PSCmdlet.MyInvocation.BoundParameters[$_].ispresent -and !($ExcludeParam -eq $_))
    {
        $SwitchConfig[$_]        
    
    }

}

if ($AllPropertiesSwitch -eq $Null -and $Properties -eq $null)
{
    $AllPropertiesSwitch=$DefaultInfoConfig   
}
$AllProperties+=$AllPropertiesSwitch+$Properties
$AllProperties = $AllProperties | Select-Object -Unique
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
$PropertyParams=$AllProperties | ParseFunctionConfig -FunctionConfig $FunctionConfig -Protocol $Protocol 
$Propertyparams.Keys | foreach {$PropertyParams[$_] | Where-Object {$_.script}} | foreach {
    $ScriptTmp=$_
    $ScriptPath=Join-Path -Path $PSScriptRoot -ChildPath "scripts\$($ScriptTmp.script)" 
    $Script=Get-Content -Path $ScriptPath -ErrorAction Stop | Out-String 
        if ((Split-Path -Path $ScriptPath) -match ".+\\(.+)")
        {
            $RootFoolder=$Matches[1]
            $FunctionName="FunctInf"+$RootFoolder+$((Split-Path -Path $ScriptPath -Leaf) -replace "\.ps1","")
            
        }
        else
        {
            Write-Error "$FunctionProperty incorrect path" -ErrorAction Stop
        }
    [void](New-Item -Path function: -Name $FunctionName -Value $Script -ErrorAction Stop)
    
    $ScriptTmp | Add-Member -MemberType NoteProperty -Name Function -Value $FunctionName
    
}

#Create wmi param
$WmiParamArray=CreateWmiObject -PropertyParams $PropertyParams -ManualNamespace $ManualNamespace
    
#Remove old ps1xml file
if (Test-Path $($env:TEMP+"\SystemInfoAutoformat.ps1xml"))
{
    Write-Verbose "Remove ps1xml file $($env:TEMP+"\SystemInfoAutoformat.ps1xml")"
    Remove-Item -Path $($env:TEMP+"\SystemInfoAutoformat.ps1xml") -Force
}

$computers=@()
$MainJobs = New-Object System.Collections.ArrayList
$GetWmicompletedForComputers = New-Object System.Collections.ArrayList
#$HashtableResult=@{}
#$HashtableWMi=@{}
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

[ScriptBlock]$SbLocalHost=
{
    $HashtableWMi=@{}
    $WmiParamArray | foreach {
        $WmiParam=$_
        if ($WmiParam.Name)
        {
            if (!($HashtableWMi.ContainsKey($($WmiParam.Name))))
            {
                #$HashtableWMi[$($WmiParam.Name)]
                $HashtableWMi.Add($WmiParam.Name,$null)
            }
        }
                
            
    }
            
    $jobs = New-Object System.Collections.ArrayList
    StartWmiJob -computername $Computername -WmiParamArray $WmiParamArray
    do
    {
        GetWmiJob
    }
    while($jobs.Count -ne 0)  
            
    CreateResult  
}

$CountComputers=0

[Array]$ExportFunctionsName="StartWmiJob","GetWmiJob","CreateResult"
    $PropertyReqHddSmartFunctions="HddDevices","HddSmartStatus","HddSmart"
    $PropertyReqRegistryFunctions="OsProductKey","SoftwareList"
    $WmiParamArray | foreach {
        if ($PropertyReqHddSmartFunctions -eq $_.property)
        {
            if (!($ExportFunctionsName -eq "GetHddSmart"))
            {
                $ExportFunctionsName+="GetHddSmart"  
            }

        }
        if ($PropertyReqRegistryFunctions -eq $_.property)
        {
            if (!($ExportFunctionsName -eq "RegGetValue"))
            {
                $ExportFunctionsName+="RegGetValue","RegEnumKey"  
            }
        }
            
    }

Write-Verbose "$protocol protocol"
if ($Protocol -eq "DCOM" -and $PSCmdlet.MyInvocation.InvocationName -ne $PSCmdlet.MyInvocation.line)
{
    $ExportFunctionsName+="StartWmi"
    $RunspaceImportVariables="WmiParamArray","Credential"    
    $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        Get-Command -CommandType Function -Name $ExportFunctionsName | foreach {
            $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $_.name, $_.Definition         
            Write-Verbose "Add Function $($_.name)"
            $SessionState.Commands.Add($SessionStateFunction)
                
        }
        Get-Command -CommandType Function -Name FunctInf* | foreach {
                $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $_.name, $_.Definition         
                Write-Verbose "Add script Function $($_.name)"
                $SessionState.Commands.Add($SessionStateFunction)
                
            }

    $SessionStateVariables=New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "WmiParamArray", $WmiParamArray, "WmiParamArray"
    $SessionState.Variables.Add($SessionStateVariables)       
    $SessionStateVariables=New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "Credential", $Credential, "Credential"
    $SessionState.Variables.Add($SessionStateVariables) 
    $SessionStateVariables=New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "VerbosePreference", $VerbosePreference, "VerbosePreference"
    $SessionState.Variables.Add($SessionStateVariables)   
    
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1,$ProcessFor,$SessionState,$Host)
    Write-Verbose "Open Runspace"
    $RunspacePool.Open()
}
else
{
    $VerboseStatus=$VerbosePreference
    $ExportFunctions=@()
    $ExportFunctionsName | foreach {$ExportFunctions+=Get-ChildItem -Path function:$_}

    $ExportScriptFunction=@()
    $ExportScriptFunction=Get-ChildItem -Path function:\FunctInf*
    
    [Array]$ExportVariablesName="WmiParamArray","MaxWmiJob","VerboseStatus"
    $ExportVariables=@()
    $ExportVariablesName | foreach {$ExportVariables+=Get-Variable -Name $_}
  
    $HashtableParam=@{
    ImportFunctions=$ExportFunctions
    ImportScriptFunction=$ExportScriptFunction
    ImportVariables=$ExportVariables
    }           

}


}
process
{
$computers=@()
if ($Name -ne $null)
{
    $computers+=$Name                
}

$computers| foreach {
    $ComputerName=$_
    $CountComputers++
        $AllProperties | foreach {
                if (!$IsAdmin)
                {
                    if ($LocalComputer -eq $ComputerName)
                    {
                        if ($AdminRequired -eq $_)
                        {

                            Write-Warning "$ComputerName Information may be incomplete. The $_ property requires administrator privileges. Close powershell and run as administrator"
                        
                        }
                    }
                } 
        }
  
    if ($LocalComputer -eq $ComputerName)
    {
        Write-Verbose "$Computername running local"
        &$SbLocalHost  | OutResult        
    }
    elseif ($Protocol -eq "Wsman")
    {
    #Protocol WSMAN
        if ($MainJobs.count -ge $ProcessFor)
        {
        Start-Sleep -Milliseconds 20
            do{
                $repeat=$true
                GetPsJob | OutResult
                if ($MainJobs.Count -lt $ProcessFor)
                {
                    $repeat=$false
                }
                else
                {
                    Start-Sleep -Milliseconds 20
                }   
            }while($repeat)
        
        
        }
        
        $NewJob=StartPsJob -ComputerName $ComputerName -ScriptBlock $InvokeScriptBlock -ArgumentList $HashtableParam,$ComputerName -Credential $Credential
        if ($NewJob)
        {
            [void]$MainJobs.Add($NewJob)
        }
    }
    else
    {
    #Protocol DCOM
        if ($MainJobs.count -ge $ProcessFor)
        {
        Start-Sleep -Milliseconds 10
            do{
                $repeat=$true
                GetRunspaceJob | OutResult
                if ($MainJobs.Count -lt $ProcessFor)
                {
                    $repeat=$false
                }
                else
                {
                    Start-Sleep -Milliseconds 20
                }   
            }while($repeat)
        
        
        }
        
        Write-Verbose "$Computername StartRunspaceJob"
        $RunspaceJob=StartRunspaceJob -Computername $Computername -RunspacePool $RunspacePool
        if ($?)
        {
            [void]$MainJobs.Add($RunspaceJob)
        }
        
        
        
    }   
#End Foreach
}


}
end
{

if ($MainJobs.Count -eq 1 -and $LocalComputer -eq $MainJobs[0].location)
{
    Start-Sleep -Milliseconds 10
        do
        {
            GetPsJob | OutResult
      
        }
        while($MainJobs.Count -ne 0)
}
elseif ($Protocol -eq "Wsman" -and $MainJobs.Count -ne 0)
{
    Start-Sleep -Milliseconds 10
    do
    {
        GetPsJob | OutResult
      
    }
    while($MainJobs.Count -ne 0)  
}
elseif ($mainjobs.Count -ne 0)
{
    do
    {
        Start-Sleep -Milliseconds 10
        GetRunspaceJob | OutResult
    }
    while($MainJobs.Count -ne 0) 
    Write-Verbose "RunspacePool close"
    $RunspacePool.Close()
}

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
        
if ($ExecutionPolicyChanged)
{
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $CurrentExecutionPolicy -Force -Confirm:$false -ErrorAction SilentlyContinue
}
#Write-Verbose "Clear all failed wmi job"
#Get-Job | Where-Object {$_.State -eq "Failed"} | Remove-Job -Force
if ($ResultCount -gt 1)
{
    Write-Verbose  "Function running  $((New-TimeSpan -Start $BeginFunction).TotalSeconds) seconds" -Verbose
    Write-Verbose  "Total Computers   $CountComputers" -Verbose
    Write-Verbose  "Success           $ResultCount" -Verbose
    Write-Verbose  "Errors            $ErrResCount" -Verbose
}

#End Function
}




}