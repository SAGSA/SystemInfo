function CreateErrorObject 
{
param($Err,$ComputerName,$Protocol,$ExceptionJob)
if ($Protocol -eq "Wsman")
{
$WsmanErrorCodes=@{
"5"="access denied"
"53"="unreachable"
"-2144108103"="unreachable"
"-2144108250"="connection failed"
}
    if ($err.Exception.ErrorCode)
    {
        if ($WsmanErrorCodes["$($err.Exception.ErrorCode)"])
        {
            $WarningMessage=$WsmanErrorCodes["$($err.Exception.ErrorCode)"]
        }
        else
        {
            $WarningMessage=$err.Exception.Message
        }
    
    }
    else
    {
        $WarningMessage=$err.Exception.Message
    }
    if ($ExceptionJob)
    {
    $MainJobs.remove($ExceptionJob)
    }  

}
elseif($Protocol -eq "Dcom")
{
$RunspaceErrorCodes=@{}
    if ($err.Exception.ErrorCode)
    {
        if ($RunspaceErrorCodes["$($err.Exception.ErrorCode)"])
        {
            $WarningMessage=$RunspaceErrorCodes["$($err.Exception.ErrorCode)"]
        }
        else
        {
            $WarningMessage=$err.Exception.Message
        }
    
    }
    else
    {
        $WarningMessage=$err.Exception.Message
    }
    if ($ExceptionJob)
    {
    

   
    
    if ($Err.Exception.Message -eq "Timeout expired")
    {
        # Закоментировал так как иногда из за этого powershell закрывается с ошибкой
        #Write-Verbose "$($ExceptionJob.location) begin stop timeout job"
        #$Callback = {(New-Object System.Threading.ManualResetEvent($false)).Set()}
        #[void]$ExceptionJob.powershell.BeginStop($callback,$null)
    }
    else
    {
         Write-Verbose "$($ExceptionJob.location) Dispose Error Job"
        $ExceptionJob.powershell.dispose()
    }
    $ExceptionJob.State = $null
    $ExceptionJob.powershell = $null
    $MainJobs.remove($ExceptionJob)
    }    
}
Write-Warning -Message "$Computername $WarningMessage"
$ErTmp="" | select ComputerName,Warning,Error
$ErTmp.ComputerName=$ComputerName
$ErTmp.Warning=$WarningMessage
$ErTmp.Error=$err
$Global:ErrorResult+=$ErTmp



}