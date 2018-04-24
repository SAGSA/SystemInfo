try
{
    [string[]]$ExcludeSid="S-1-5-18","S-1-5-19","S-1-5-20"
    if ($credential)
    {
        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true" -Credential $credential
    }
    else
    {
        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true"
    }
    
    $Win32_UserProfile | Where-Object {!($ExcludeSid -eq $_.sid)} | Select-Object -Property * | foreach {
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
       
       if ($LocalPath -ne $null)
       {
           $LastUseTime=$null
           $ProfilePath=$LocalPath -replace "\\","\\"
           if ($credential)
           {
            $ProfileDirectory=Get-WmiObject -Class Win32_Directory -Filter "Name='$ProfilePath'" -ComputerName $Computername -ErrorAction Stop -Credential $credential
           }
           else
           {
            $ProfileDirectory=Get-WmiObject -Class Win32_Directory -Filter "Name='$ProfilePath'" -ComputerName $Computername -ErrorAction Stop
           }
           
           if ($ProfileDirectory -ne $null)
           {
            $LastUseTime=([wmi]'').ConvertToDateTime($ProfileDirectory.LastModified)
           }
           
       }
       
       $_ | Add-Member -MemberType NoteProperty -Name LastModified -Value $LastUseTime
       $_
    } | Sort-Object -Property LastModified -Descending | Select-Object -Property User,LocalPath,Loaded,LastModified
}
catch
{
    Write-Error $_
}
