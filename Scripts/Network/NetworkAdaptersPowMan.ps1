$Win32_NetworkAdapter | foreach {
    $Adapter=$_
    $WakeOnMagicPacket=$null
    $WakeOnPattern=$null
    if ($Adapter.PhysicalAdapter -and $Adapter.AdapterTypeID -eq "0")
    {
        [string]$DeviceId=$_.DeviceId
        $ZerroString=$null
        if ($DeviceId.Length -lt 4)
        {
            1..$(4-$DeviceId.Length) | foreach {[string]$ZerroString+="0"}
        }
        $Key="HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\"+$ZerroString+$DeviceId
        $WakeOnMagicPacketValue=RegGetValue -Key $Key -Value *WakeOnMagicPacket -GetValue GetStringValue -ErrorAction SilentlyContinue
        $WakeOnPatternValue=RegGetValue -Key $Key -Value *WakeOnPattern -GetValue GetStringValue -ErrorAction SilentlyContinue
        if ($WakeOnMagicPacketValue -ne $null -or $WakeOnMagicPacketValue -ne $null)
        {
                if ($WakeOnMagicPacketValue -ne $null)
                {
                    if([int]$WakeOnMagicPacketValue -eq 1)
                    {
                        $WakeOnMagicPacket=$true  
                    }
                    elseif ([int]$WakeOnMagicPacketValue -eq 0)
                    {
                        $WakeOnMagicPacket=$false   
                    }
                }
                if ($WakeOnMagicPacketValue -ne $null)
                {
                    if ([int]$WakeOnPatternValue -eq 1)
                    {
                        $WakeOnPattern=$true
                    }
                    elseif([int]$WakeOnPatternValue -eq 0)
                    {
                        $WakeOnPattern=$false
                    }   
                }
        
            Write-Verbose "CreateObject"
            $TmpObject=New-Object -TypeName psobject
            $TmpObject | Add-Member -MemberType NoteProperty -Name Index -Value $Adapter.deviceid    
            $TmpObject | Add-Member -MemberType NoteProperty -Name Name -Value $Adapter.name
            $TmpObject | Add-Member -MemberType NoteProperty -Name MACAddress -Value $Adapter.MACAddress
            $TmpObject | Add-Member -MemberType NoteProperty -Name WakeOnMagicPacket -Value $WakeOnMagicPacket 
            $TmpObject | Add-Member -MemberType NoteProperty -Name WakeOnPattern -Value $WakeOnPattern 

            
            
            $MSPowerEnable=($MSPower_DeviceEnable | Where-Object {$_.instancename -match [regex]::escape($Adapter.PNPDeviceID)}).enable
            $MSPowerWakeEnable=($MSPower_DeviceWakeEnable | Where-Object {$_.instancename -match [regex]::escape($Adapter.PNPDeviceID)}).enable
            $WakeOnMagicPacketOnly=($MSNdis_DeviceWakeOnMagicPacketOnly | Where-Object {$_.instancename -match [regex]::escape($Adapter.PNPDeviceID)}).EnableWakeOnMagicPacketOnly
            if ($MSPowerEnable -eq $false)
            {
                $MSPowerWakeEnable=$false
                $WakeOnMagicPacketOnly=$false
            }
            if ($MSPowerWakeEnable -eq $false)
            {
                $WakeOnMagicPacketOnly=$false
            }
            $TmpObject | Add-Member -MemberType NoteProperty -Name MSPowerEnable -Value $MSPowerEnable
            $TmpObject | Add-Member -MemberType NoteProperty -Name MSPowerWakeEnable -Value $MSPowerWakeEnable
            $TmpObject | Add-Member -MemberType NoteProperty -Name WakeOnMagicPacketOnly -Value $WakeOnMagicPacketOnly
            $TmpObject 
        }
    
    }

    
}