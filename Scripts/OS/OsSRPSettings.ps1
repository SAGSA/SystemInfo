#$Computername=$env:COMPUTERNAME
#$Win32_UserProfile=Get-WmiObject -Class Win32_UserProfile
#$StdregProv=Get-WmiObject -Class Stdregprov -List
try
{
    $SRPKeyPath="HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\safer\codeidentifiers"   
    $SRPKey=RegGetValue -Key $SRPKeyPath -Value DefaultLevel -GetValue GetDWORDValue -ErrorAction SilentlyContinue
    $ComputerSrpEnable=$false
    if ($SRPKey -eq 0)
    {
        $ComputerSrpEnable=$true
    }
    
    [string[]]$ExcludeSid="S-1-5-18","S-1-5-19","S-1-5-20"
    if ($credential)
    {
        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true" -Credential $credential
    }
    else
    {
        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true"
    }
    
    $LoadedProfile=$Win32_UserProfile |Select-Object -Property * | Where-Object {!($ExcludeSid -eq $_.sid) -and $_.loaded}
    if ($LoadedProfile -eq $null -and !$ComputerSrpEnable)
    {
        Write-Error "No uploaded user profile" -ErrorAction Stop        
    }
    elseif($ComputerSrpEnable)
    {
        $Obj="" | Select-Object -Property User,Loaded,SrpEnable
        $Obj.User=[string]$('$'+$computername)
        $Obj.SrpEnable=$ComputerSrpEnable
        $Obj
    }
    $LoadedProfile | foreach {
        $Sid=$_.sid
        $LastUseTime=$null
        $User=$null
        $ProfileDirectory=$null
        $LocalPath=$_.localpath
        $objSID = New-Object System.Security.Principal.SecurityIdentifier($Sid) 
        try
        {
            $objUser = $objSID.Translate([System.Security.Principal.NTAccount])
            $User=$objUser.Value
            Write-Verbose "$Computername Translate sid $sid succesfully"
        }
        catch
        {
            Write-Verbose "$Computername Unknown sid $sid"
            $User=($LocalAccount | Where-Object {$_.sid -eq $Sid}).caption
            if ($User -eq $null)
            {
                $User="Unknown"
            }
        }
       
        $_ | Add-Member -MemberType NoteProperty -Name User -Value $User
        $_
    } | foreach {
        if ($ComputerSrpEnable)
        {
            $SrpEnable=$true
        }
        else
        {
            $SRPKeyPath="HKEY_USERS\$($_.sid)\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers"   
            $SRPKey=RegGetValue -Key $SRPKeyPath -Value DefaultLevel -GetValue GetDWORDValue -ErrorAction SilentlyContinue
            if ($SRPKey -eq 0)
            {
                $SrpEnable=$true    
            }
            else
            {
                $SrpEnable=$false        
            }
        }
            
        $_ | Add-Member -MemberType NoteProperty -Name SrpEnable -Value $SrpEnable
        $_
    } | Sort-Object -Property SrpEnable -Descending | Select-Object -Property User,SrpEnable
    
     
}
catch
{
    Write-Error $_
}
