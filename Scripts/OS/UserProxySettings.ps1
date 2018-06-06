#$Computername=$env:COMPUTERNAME
#$Win32_UserProfile=Get-WmiObject -Class Win32_UserProfile
#$StdregProv=Get-WmiObject -Class Stdregprov -List
try
{
    [string[]]$ExcludeSid="S-1-5-18","S-1-5-19","S-1-5-20"    
    $AutoDetectSettingsHash=@{
    1=$False
    3=$False
    11=$true
    9=$true
    }
    $LoadedProfile=$Win32_UserProfile | Select-Object -Property * | Where-Object {!($ExcludeSid -eq $_.sid) -and $_.loaded} 
    if ($LoadedProfile -eq $null)
    {
        Write-Error "No uploaded user profile" -ErrorAction Stop        
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
                if ($LocalAccount -eq $null)
                {
                    if ($credential)
                    {
                        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true" -Credential $credential
                    }
                    else
                    {
                        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true"
                    }
                }
            $User=($LocalAccount | Where-Object {$_.sid -eq $Sid}).caption
            if ($User -eq $null)
            {
                $User="Unknown"
            }
        }
       
       $_ | Add-Member -MemberType NoteProperty -Name User -Value $User
       $_
    } | foreach {
        $ISKey="HKEY_USERS\$($_.sid)\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
        #$ISKey
        $ProxyEnable=RegGetValue -Key $ISKey -Value ProxyEnable -GetValue GetDWORDValue -ErrorAction SilentlyContinue
        $ProxyServer=RegGetValue -Key $ISKey -Value ProxyServer -GetValue GetStringValue -ErrorAction SilentlyContinue
        $DefConnectSet=RegGetValue -Key "$ISKey\connections" -Value DefaultConnectionSettings -GetValue GetBinaryValue -ErrorAction SilentlyContinue
        if ($DefConnectSet -ne $null)
        {
            $AutoDetectSettings=$AutoDetectSettingsHash[[int]$($DefConnectSet[8])]
        }
        if ($proxyenable -eq 1)
        {
           $proxyenable=$true 
        }
        else
        {
           $proxyenable=$false 
        } 
        $_ | Add-Member -MemberType NoteProperty -Name Proxy -Value $ProxyServer
        $_ | Add-Member -MemberType NoteProperty -Name AutoDetectSettings -Value $AutoDetectSettings
        $_ | Add-Member -MemberType NoteProperty -Name ProxyEnable -Value $ProxyEnable   
        $_
    } | Select-Object -Property User,Proxy,AutoDetectSettings,ProxyEnable | Sort-Object -Property ProxyEnable -Descending
}
catch
{
    Write-Error $_
}