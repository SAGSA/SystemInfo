#$ComputerName=$env:COMPUTERNAME
#$Win32_LocalTime=Get-WmiObject -Class Win32_LocalTime -Namespace root\cimv2 -ComputerName $ComputerName
#$Win32_ComputerSystem=Get-WmiObject -Class Win32_ComputerSystem -Namespace root\cimv2 -ComputerName $ComputerName

$LastInteractiveUser=$Win32_ComputerSystem.username 
if ($LastInteractiveUser -eq $null)
{
    if ($Protocol -eq "WSMAN")
    {
        try
        {
            $Script:FoundEvent=$false
            Get-EventLog -LogName Security -InstanceId 4624  | Where-Object {$_.ReplacementStrings -eq 2} | foreach {
                Write-Verbose "$Computername Found Type2 event"
                $Type2Event=$_
                [array]$Messages=$Type2Event.ReplacementStrings | Select-Object -First 10 
                $SelectMessage=$Messages | Select-String -Pattern "S-1-5-21.+" -Context 2
                if ($SelectMessage -ne $null)
                {
                    Write-Verbose "$Computername Found interactive user"
                    $UserName=$SelectMessage.Context.PostContext[0]
                    $UserDomain=$SelectMessage.Context.PostContext[1]
                    $UserSid=$SelectMessage.Line
                    $FullName=$UserDomain+"\$UserName"
                    #$LoginTime=$WmiObject.ConvertToDateTime($($Type2Event.TimeGenerated))
                    #$PsObject=New-Object -TypeName psobject
                    #$PsObject | Add-Member -MemberType NoteProperty -Name FullName -Value $FullName
                    #$PsObject | Add-Member -MemberType NoteProperty -Name LoginTime -Value $LoginTime
                    #$PsObject
                    $FullName
                    $Script:FoundEvent=$True
                    throw
                }
            
    

            }
        }catch{}
        if (!($Script:FoundEvent))
        {
            Write-Verbose "$Computername Interactive user not found" -Verbose
        }
    }
    else
    {
        [int]$SeeHours=12
        [int]$MaxHours=1440 #(60 days)
        if ($Credential)
        {
            $Win32_LocalTime=Get-WmiObject -Class Win32_LocalTime -Namespace root\cimv2 -ComputerName $ComputerName -Credential $Credential   
        }
        else
        {
            $Win32_LocalTime=Get-WmiObject -Class Win32_LocalTime -Namespace root\cimv2 -ComputerName $ComputerName
        }
        $currentDate= Get-Date -Year $Win32_LocalTime.Year -Month $Win32_LocalTime.Month -Day $Win32_LocalTime.Day -Hour $Win32_LocalTime.Hour -Minute $Win32_LocalTime.Minute -Second $Win32_LocalTime.Second
        [int]$Script:CurentHoursCount=0
        function GetEvent
        {
            [cmdletbinding()]
            param(
            [parameter(Mandatory=$true)]
            [int]$SeeHours,
            [parameter(Mandatory=$true)]
            $StartDate,
            [parameter(Mandatory=$true)]
            [int]$MaxHours
            )
    
            [wmi]$WmiObject=''
            $DateHoursAgo=$StartDate.AddHours(-$SeeHours)
            $WmiStartDate=$WmiObject.ConvertFromDateTime($StartDate)
            $WmiDateHoursAgo=$WmiObject.ConvertFromDateTime($DateHoursAgo)
            Write-Verbose "$ComputerName GetEvents Start $StartDate End $DateHoursAgo"
            if ($Credential)
            {
                [array]$LogEntries=get-wmiobject -query "Select * From Win32_NTLogEvent Where LogFile = 'Security' and TimeWritten < '$WmiStartDate' And TimeWritten > '$WmiDateHoursAgo'  And EventCode = 4624" -Namespace root\cimv2 -ErrorAction Stop -ComputerName $ComputerName -Credential $Credential
            }
            else
            {
                [array]$LogEntries=get-wmiobject -query "Select * From Win32_NTLogEvent Where LogFile = 'Security' and TimeWritten < '$WmiStartDate' And TimeWritten > '$WmiDateHoursAgo'  And EventCode = 4624" -Namespace root\cimv2 -ErrorAction Stop -ComputerName $ComputerName
            }
    
            if ($LogEntries.count -ge 1)
            {
                $Type2Events=$LogEntries | Where-Object {$_.InsertionStrings -eq 2}
                if ($Type2Events -ne $null)
                {
                    foreach ($Type2Event in $Type2Events)
                    {
                        [array]$Messages=$Type2Event.InsertionStrings | Select-Object -First 10   
    
                        $SelectMessage=$Messages | Select-String -Pattern "S-1-5-21.+" -Context 2
                        if ($SelectMessage -ne $null)
                        {
                            $UserName=$SelectMessage.Context.PostContext[0]
                            $UserDomain=$SelectMessage.Context.PostContext[1]
                            $UserSid=$SelectMessage.Line
                            $FullName=$UserDomain+"\$UserName"
                            #$LoginTime=$WmiObject.ConvertToDateTime($($Type2Event.TimeGenerated))
                            #$PsObject=New-Object -TypeName psobject
                            #$PsObject | Add-Member -MemberType NoteProperty -Name FullName -Value $FullName
                            #$PsObject | Add-Member -MemberType NoteProperty -Name LoginTime -Value $LoginTime
                            #$PsObject
                            $FullName
                            $Script:FoundEvent=$True
                            break
                        }
                   
                    }
        
                }
                else
                {
                    Write-Verbose "No interactive logon records for last $SeeHours hour(s)"
                }

    
            }
    
            $Script:CurentHoursCount+=$SeeHours
            Write-Verbose "$Script:CurentHoursCount $SeeHours"
            $LastLogEntry=$LogEntries | Select-Object -Last 1
            if ($Script:CurentHoursCount -lt $MaxHours -and !($Script:FoundEvent))
            {
                GetEvent -StartDate $DateHoursAgo -SeeHours $SeeHours -MaxHours $MaxHours
            }
            elseif(!($Script:FoundEvent))
            {
                Write-Verbose "$ComputerName Interactive user not found for last $MaxHours Hour(s)" -Verbose
            }
    
        }
        GetEvent -StartDate $CurrentDate -SeeHours $SeeHours -MaxHours $MaxHours  
    }
     

}
else
{
    $LastInteractiveUser
}
