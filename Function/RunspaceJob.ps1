function StartWmi
{
[cmdletbinding()]
param(
$Computername,
$WmiParamArray
)
$WmiParamArray | Sort-Object -Property name -Unique | foreach {
    $WmiName=$_.name
    if ($_.class)
    {
        $WmiParam=$_
        $Wmi=@{}
        if ($Credential -ne $null)
        {  
            $Wmi.Add("Credential",$Credential)
            <#if (!($WmiParam["Credential"]))
            {
                
            }#>          
        }
    }
    if ($WmiParam.Query)
    {
        $Wmi.add("Query",$WmiParam.Query)  
        Write-Verbose "$Computername Start Get-WmiObject -Query $($WmiParam.Query) -NameSpace $($WmiParam.Namespace)"
    }
    elseif ($WmiParam.class)
    {
        if ($WmiParam.class -eq "StdRegprov")
        {
            $Wmi.Add("Query",'SELECT * FROM meta_class WHERE __class="StdRegProv"')
            Write-Verbose "$Computername Start Get-WmiObject -Query SELECT * FROM meta_class WHERE __class=StdRegProv -NameSpace $($WmiParam.Namespace)" 
        }
        else
        {
            $Wmi.add("Class",$WmiParam.Class) 
            Write-Verbose "$Computername Start Get-WmiObject -Class $($WmiParam.Class) -NameSpace $($WmiParam.Namespace)" 
        }
            
              
    }
    $Wmi.add("Namespace",$WmiParam.Namespace)

    $TmpRes=Get-WmiObject @Wmi -ComputerName $computername -ErrorAction SilentlyContinue
    if ($?)
    {
        $HashtableWMi[$wmiName]=$tmpres
    }
    elseif($Error[0].Exception.ErrorCode -ne "NotSupported")
    {
       Write-Error $Error[0]
    }
        
}

}
function StartRunspaceJob
{
param(
$Computername,
$RunspacePool
)
    $PowerShell = [powershell]::Create()
    [void]$PowerShell.AddScript($SbRunspace)
    $ParamList=@{}
    $ParamList.Add("Computername",$(get-variable -Name Computername -ValueOnly))
    [void]$PowerShell.AddParameters($ParamList)
    $PowerShell.Runspacepool = $RunspacePool
    $State = $PowerShell.BeginInvoke()
    $temp = '' | Select PSJobTypeName,PowerShell,State,Location,StartTime,Property,Runspace
    $temp.PSJobTypeName="RunspaceJob"
    $temp.powershell=$PowerShell
    $temp.state=$State
    $temp.location=$Computername
    $temp.StartTime=get-date
    $temp.runspace=$Runspace
    $temp

}

function GetRunspaceJob
{
try
{
$AllCompletedRunspaceJob=$MainJobs | Where-Object {$_.State.IsCompleted}
if ($AllCompletedRunspaceJob)
{
    Write-Verbose -Message "Available Completed Job"
    $AllCompletedRunspaceJob | foreach{
        $Job=$_
        Write-Verbose "$($_.location) End Invoke"
        $TmpRes=$_.powershell.EndInvoke($_.State)
        if($_.PowerShell.Streams.Error[0] -ne $null)
        {
            write-error "$($_.PowerShell.Streams.Error[0])" -ErrorAction Stop
            <#if ($TmpRes.count -eq 0)
            {
                Write-Error "Scriptblock HadErrors, use try{}catch{} in the ScriptBlock to find out the details" -ErrorAction Stop
            }
            elseif ($TmpRes[0].GetType().name -eq "ErrorRecord")
            {
                Write-Error $TmpRes[0] -ErrorAction Stop
            }
            else
            {
                Write-Error "Unknown Error $($TmpRes[0])" -ErrorAction Stop
            }#>
        }
        elseif($TmpRes[0] -ne $null)
        {
            if ($TmpRes[0].GetType().name -eq "ErrorRecord")
            {
                Write-Error $TmpRes[0] -ErrorAction Stop
            }
            Write-Verbose "$($Job.location) RunspaceJob Completed"
            $TmpRes
            Write-Verbose "$($_.location) Dispose completed job"
            $_.powershell.dispose()
            $_.State = $null
            $_.powershell = $null
            $MainJobs.Remove($Job)
                
        }
        else
        {
            Write-Error "Scriptblock return empty value" -ErrorAction Stop
        }
    }

}

$AllTimeOutJob=$MainJobs | Where-Object {(New-TimeSpan -start $_.StartTime).TotalSeconds -gt $JobTimeOut}
    if($AllTimeOutJob)
    {
        
        $AllTimeOutJob | foreach {
                try
                {
                    
                    $Job=$_
                    Write-Error -Message "Timeout expired" -ErrorAction Stop
                }
                catch
                {
                   CreateErrorObject -Err $_ -ComputerName $Job.Location -Protocol $Protocol -ExceptionJob $Job
                }

        }
    }
}
Catch
{
    CreateErrorObject -Err $_ -ComputerName $Job.Location -Protocol $Protocol -ExceptionJob $Job
} 

}

[scriptblock]$SbRunspace=
{
param($Computername)
try
{
    
    
    $HashtableWMi=@{}
    $WmiParamArray | foreach {
        $WmiParam=$_
        if ($WmiParam.Name)
        {
            if (!($HashtableWMi.ContainsKey($($WmiParam.Name))))
            { 
                $HashtableWMi.Add($WmiParam.Name,$null)
            }
        }
                
            
    }
    StartWmi -WmiParamArray $WmiParamArray -Computername $Computername -ErrorAction Stop
    CreateResult
}
catch
{
    write-error $_
}

}