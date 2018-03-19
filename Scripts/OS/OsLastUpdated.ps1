try
{
    $CurrentDate=Get-date
    if ($Win32_QuickFixEngineering | where-object {$_.installedon -ne $null} | Where-Object {$_.installedon.gettype() -eq [datetime]})
    {
        $LastUpdate=($Win32_QuickFixEngineering | Sort-Object {$_.InstalledOn} -Descending -ErrorAction Stop | Select-Object -First 1 -ErrorAction Stop).InstalledOn
        
        if ($Protocol -eq "Wsman")
        {
            $Win32_OperatingSystem=Get-WmiObject -Class Win32_OperatingSystem
            if ([version]$Win32_OperatingSystem.Version -lt [Version]"10.0.14393" -and $Win32_OperatingSystem.locale -eq "0419")
            {
                $LastUpdate=Get-Date -Day $LastUpdate.month -Month $LastUpdate.day -Year $LastUpdate.year -Hour 0 -Minute 0 -Second 0  
            }
        }
   
    }
    else
    {
        
        $Win32_QuickFixEngineeringDate=$Win32_QuickFixEngineering | foreach {
            if ($_.installedon)
            {
                if($_.installedon -match "(.+)/(.+)/(.+)")
                {
                    $Month=$matches[1]
                    $Day=$matches[2]
                    $Year=$matches[3]    
                    $DateUpdateInstalled=get-date -Day $Day -Month $Month -Year $Year -Hour 0 -Minute 0 -Second 0
                    $_ | Add-Member -MemberType NoteProperty -Name DateUpdateInstalled -Value $DateUpdateInstalled -Force
                    $_
                } 
            }
        }
        $LastUpdate=($Win32_QuickFixEngineeringDate | Sort-Object {$_.DateUpdateInstalled} -Descending -ErrorAction Stop | Select-Object -First 1 -ErrorAction Stop).DateUpdateInstalled
    }
    ($CurrentDate - $LastUpdate).Days
}
catch
{
    Write-Error $_
}
