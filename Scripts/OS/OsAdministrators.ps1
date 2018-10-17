try{
    $GroupName=$Query_Win32_Group_OsAdministrators.Name
    $Computername=$Query_Win32_Group_OsAdministrators.__SERVER
    function GetLastPasswordChange
    {
        param($LocalAccountName,$CurrentDate,$Computer)
        
        $user = ([adsi]"WinNT://$computer/$($LocalAccountName),user")
        $pwAge    = $user.PasswordAge.Value
        if ($pwAge -eq 0)
        {
            $pwLastSet=$null
        }
        else
        {
            $pwLastSet = $CurrentDate.AddSeconds(-$pwAge)
        }
        
        $pwLastSet
    }
    Write-Verbose "Administrators GroupName $GroupName"
    if ($Credential)
    {
        $wmitmp = Get-WmiObject -ComputerName $ComputerName -Query "SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`"" -ErrorAction Stop -Credential $Credential
    }
    else
    {
        $wmitmp = Get-WmiObject -ComputerName $ComputerName -Query "SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`"" -ErrorAction Stop
    }

    if ($wmitmp -ne $null)  
    {  
        $DispObjArray=@()       
        if ($Credential)
        {
            $LocalUserAccounts = Get-WmiObject -Class Win32_UserAccount -Namespace root\cimv2  -ComputerName $ComputerName -Filter "LocalAccount=$true" -ErrorAction Stop -Credential $Credential
        }
        else
        {
            Write-Verbose "Get-WmiObject -Filter LocalAccount=$true"
            $LocalUserAccounts = Get-WmiObject -Class Win32_UserAccount -Namespace root\cimv2  -ComputerName $ComputerName -Filter "LocalAccount=$true" -ErrorAction Stop
        }   
        $wmitmp | foreach{   
            if ($_.PartComponent -match '(.+:)?win32_(.+)\..+?="(.+?)",Name="(.+?)"')
            {
                $LastPasswordChange=$null
                $Type=$Matches[2]
                $Type=$Type -replace "User",""
                $Domain=$matches[3]
                $Name=$Matches[4]
                $FullName="$Domain\$Name"
                $AccountStatus=$null
                $PasswordRequired=$null
                    if ($domain -eq $computername)
                    {
                        $IsLocalAccount=$True
                    
                    }
                    else
                    {
                        $IsLocalAccount=$false
                    }
                    if ($type -eq "Account" -and $IsLocalAccount)
                    {
                        $UserAccount=$LocalUserAccounts | Where-Object {$_.caption -eq $FullName}
                        $AccountStatus=$UserAccount.status   
                        if ($protocol -eq "WSMAN")
                        {
                            $Now=Get-Date
                            $LastPasswordChange=GetLastPasswordChange -LocalAccountName $UserAccount.name -CurrentDate $Now -Computer $Computername
                        }
                    
                    } 
                $DispObj=New-Object psobject 
                $DispObj | Add-Member -MemberType NoteProperty -Name FullName -Value "$Domain\$Name"
                $DispObj | Add-Member -MemberType NoteProperty -Name Type -Value $Type
                $DispObj | Add-Member -MemberType NoteProperty -Name IsLocal -Value $IsLocalAccount
                if ($protocol -eq "WSMAN")
                {
                    $DispObj | Add-Member -MemberType NoteProperty -Name LastPassChange -Value $LastPasswordChange  
                }
                $DispObj | Add-Member -MemberType NoteProperty -Name Status -Value $AccountStatus
                $DispObjArray+=$DispObj 
            }
                
        }  
        $DispObjArray | Sort-Object -Property IsLocal,Type -Descending
    } 
    else
    {
        Write-Error -Message "Query SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`" return null value" -ErrorAction Stop
    } 
}
catch
{
    Write-Error $_
}