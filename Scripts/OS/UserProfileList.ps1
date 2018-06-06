try
{
    GetUserProfile | foreach {
        $LocalPath=$_.LocalPath
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
