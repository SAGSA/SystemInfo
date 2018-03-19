try
{
    #$CurrentDate=Get-date
    if ($Win32_QuickFixEngineering | where-object {$_.installedon -ne $null} | Where-Object {$_.installedon.gettype() -eq [datetime]})
    {
        $LastTenUpdate=$Win32_QuickFixEngineering | Sort-Object {$_.InstalledOn} -Descending -ErrorAction Stop | Select-Object -First 10 -ErrorAction Stop
        
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
        $LastTenUpdate=$Win32_QuickFixEngineeringDate | Sort-Object {$_.DateUpdateInstalled} -Descending -ErrorAction Stop | Select-Object -First 10 -ErrorAction Stop
    }
    if ($LastTenUpdate)
    {
        $LastTenUpdate | Select-Object Description,HotFixID,InstalledBy,InstalledOn
    }
    else
    {
        Write-Error "NoLastUpdate" -ErrorAction Stop
    }
    
}
catch
{
    Write-Error $_
}