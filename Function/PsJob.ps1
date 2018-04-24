function StartPsJob
{
param(
$ComputerName,
$ScriptBlock,
$ArgumentList,
$PSSessionOption,
$Credential
)
try
{
    Write-Verbose "$Computername InvokeCommand"   
    $InvokeParam=@{
    ComputerName=$ComputerName
    ScriptBlock=$InvokeScriptBlock
    ArgumentList=$ArgumentList
    ThrottleLimit=254
    }
    if ($Credential)
    {
        $InvokeParam.Add("Credential",$Credential)     
    }
    if ($PSBoundParameters["PSSessionOption"])
    {
        $InvokeParam.Add("SessionOption",$PSSessionOption)   
    }
    $TmpPsJob=Invoke-Command @InvokeParam -AsJob -ErrorAction Stop
    $temp = '' | Select-Object PSJobTypeName,PsJob,StartTime,Location
    $temp.PSJobTypeName="PsJob"
    $temp.PsJob=$TmpPsJob
    $temp.StartTime=Get-Date
    $Temp.Location=$ComputerName
    $temp
    
}
catch
{
    CreateErrorObject -Err $_ -ComputerName $ComputerName -Protocol $protocol
}

}
function GetPsJob
{
try
{
$AllFailedPsJobs=$MainJobs | Where-Object  {$_.PsJob.State -eq "Failed"}
if ($AllFailedPsJobs)
    {
        $AllFailedPsJobs | foreach {
          
            $Job=$_
            $PsJob=$_.PsJob
            $TmpErRec=$PsJob| Receive-Job -ErrorAction Stop
                if ($TmpErRec -eq $null)
                {
                    Write-Warning "$($PsJob.location) Job state failed, no error returned"
                }
            Remove-Job $PsJob
            $MainJobs.Remove($Job)
            
            
            

        # End Foreach
        }
    }
$AllCompletedJobs=$MainJobs | Where-Object {$_.PsJob.State -eq "Completed"} 
    if ($AllCompletedJobs)
    {
        $AllCompletedJobs | foreach {
            $Job=$_
            $PsJob=$_.PsJob
            $Computername=$Job.location
            $ReceivePsJob=@()
            $ReceivePsJob+=Receive-Job -Job $PsJob -ErrorAction Stop
            
            if ($ReceivePsJob.Count -eq 0 -or $ReceivePsJob[0] -eq $null)
            {
                Write-Warning -Message "$Computername InvokeCommand return empty value.."
            }
            else
            {     

                Write-Verbose "$Computername Information Completed"
                $ReceivePsJob
            }
        
            Remove-Job $PsJob -Force
            $MainJobs.Remove($Job)
            
            
    
        # End Foreach
        }   
    }
$AllTimeOutJob=$MainJobs | Where-Object {(New-TimeSpan -start $_.StartTime).TotalSeconds -gt $JobTimeOut}
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
                CreateErrorObject -Err $_ -ComputerName $Job.Location -Protocol $Protocol -ExceptionJob $Job
            }

        }
    }
}
catch
{
    CreateErrorObject -Err $_ -ComputerName $Job.Location -Protocol $Protocol -ExceptionJob $Job
}

}

function StartWmiJob
{
param ($Computername,
$WmiParamArray
)
$WmiParamArray | Sort-Object -Property name -Unique | foreach {
    if ($_.class)
    {
        $WmiParam=$_
        $Wmi=@{}
        if ($Credential -ne $null)
        {  
            if (!($LocalComputer -eq $ComputerName))
            {   
                if (!($WmiParam["Credential"]))
                {
                    $WmiParam.Add("Credential",$Credential)
                }   
            }    
        }
        if ($jobs.count -ge $MaxWmiJob)
        {
            do{
                $repeat=$true
                GetWmiJob
                    if ($Jobs.Count -lt $MaxWmiJob)
                    {
                        $repeat=$false
                    }
                    else
                    {
                        Start-Sleep -Milliseconds 20
                    }   
            }while($repeat)
        }
    
        if ($WmiParam.Query)
        {
            $Wmi.add("Query",$WmiParam.Query)  
            Write-Verbose "$Computername Start Job Get-WmiObject -Query $($WmiParam.Query) -NameSpace $($WmiParam.Namespace)"
        }
        elseif ($WmiParam.class)
        {
            if ($WmiParam.class -eq "StdRegprov")
            {
                $Wmi.Add("Query",'SELECT * FROM meta_class WHERE __class="StdRegProv"')
                Write-Verbose "$Computername Start Job Get-WmiObject -Query SELECT * FROM meta_class WHERE __class=StdRegProv -NameSpace $($WmiParam.Namespace)" 
            }
            else
            {
                $Wmi.add("Class",$WmiParam.Class) 
                Write-Verbose "$Computername Start Job Get-WmiObject -Class $($WmiParam.Class) -NameSpace $($WmiParam.Namespace)" 
            }
            
              
        }
        $Wmi.add("Namespace",$WmiParam.Namespace)
        $TmpWmiJob=Get-WmiObject @Wmi -computername $ComputerName -ErrorAction Stop -AsJob   
        if ($?)
        {
            $temp = '' | Select-Object PSJobTypeName,WmiJob,StartTime,Location,Class,WmiName
            $temp.PSJobTypeName="WmiJob"
            $temp.WmiJob=$TmpWmiJob
            $temp.StartTime=Get-Date
            $Temp.Location=$ComputerName
            $temp.WmiName=$WmiParam.name    
            [void]$Jobs.Add($temp) 
        }
    }
    
    
}

}
Function GetWmiJob
{
    
    $AllFailedWmiJobs=$Jobs | Where-Object  {$_.WmiJob.State -eq "Failed"}
    if ($AllFailedWmiJobs)
    {
        $AllFailedWmiJobs | foreach {
            try
            {
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
            } 
            catch 
            {
                Write-Error $_ -ErrorAction Stop
            }
        # End Foreach
        }
    }
    
    $AllCompletedJobs=$Jobs | Where-Object {$_.WmiJob.State -eq "Completed"} 
    if ($AllCompletedJobs)
    {
        $AllCompletedJobs | foreach {
            $wminame=$_.wminame
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
            elseif($GetWmi.count -eq 1)
            {
                Write-Verbose "$Computername Receive-Job $wminame Completed"
                $HashtableWMi[$wminame]=$GetWmi[0]
            }
            else
            {
                Write-Verbose "$Computername Receive-Job $wminame Completed"
                $HashtableWMi[$wminame]=$GetWmi
            }
        
            Remove-Job $Job -Force
            
            $Jobs.Remove($_)
            
            
    
        # End Foreach
        }   
    }

   
}


[Scriptblock]$InvokeScriptBlock=
{
    param ($HashtableParam,$ComputerName)  
    try
    {
        #Create Functions
        $HashtableParam['ImportFunctions'] | foreach {
            Write-Verbose "Exporting function $($_.name)"
            [void]$(New-Item -path function: -name $_.name -Value $_.definition -ErrorAction Stop)
        }
        #Create Scriptblock variables

                            
        $HashtableParam['ImportScriptFunction'] | foreach {
            if ($_.name)
            {
                Write-Verbose "Exporting function $($_.name)"
                [void]$(New-Item -path function: -name $_.name -Value $_.definition -ErrorAction Stop)
            }
                            
                            
        } 
                       
                         
                        
        $HashtableParam['ImportVariables'] | foreach {
            Write-Verbose "Exporting Variable $($_.name)"
            New-Variable -Name $_.name -Value $_.value
        }
    }
    catch
    {
        Write-Error "$_ Error create functions or scriptblock variable" -ErrorAction Stop
    }
    
    $VerbosePreference=$VerboseStatus
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
