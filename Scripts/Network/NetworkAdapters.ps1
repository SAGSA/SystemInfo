function GetStatusFromValue
{
Param($SV)
    switch($SV)
    {
        0 { "Disconnected" }
        1 { "Connecting" }
        2 { "Connected" }
        3 { "Disconnecting" }
        4 { "Hardware not present" }
        5 { "Hardware disabled" }
        6 { "Hardware malfunction" }
        7 { "Media disconnected" }
        8 { "Authenticating" }
        9 { "Authentication succeeded" }
        10 { "Authentication failed" }
        11 { "Invalid Address" }
        12 { "Credentials Required" }
        Default { "Not connected" }
    }
}
function GetSpeedDuplexFromValue
{
Param($SV)
    switch($SV)
    {      
        0 {"AutoNegotiation"}
        1 {"10Mbps HalfDuplex"}
        2 {"10Mbps FullDuplex"}
        3 {"100Mbps HalfDuplex"}
        4 {"100Mbps FullDuplex"}
        6 {"1Gbps FullDuplex"}
        Default { $SV }
    }
}
function GetAdapterTypeFromValue
{
Param($SV)
    switch($SV)
    {      
        0 {"Ethernet"}
        16{"Wireless"}
        Default { $SV }
    }
}

$AdaptersHashTable=@{}
$Win32_NetworkAdapter | foreach {
    $Adapter=$_
    $ZerroString=$null
    $SpeedDuplex=$null
    $AdapterType=$null
    $LinkSpeed=($MSNdis_LinkSpeed | Where-Object {$_.InstanceName -eq $Adapter.Name}).NdisLinkSpeed/10000
    if ($Adapter.PhysicalAdapter)
    {
        [string]$DeviceId=$_.DeviceId
        if ($DeviceId.Length -lt 4)
        {
            1..$(4-$DeviceId.Length) | foreach {[string]$ZerroString+="0"}
        }
        $Key="HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\"+$ZerroString+$DeviceId
        
        $SpeedDuplexValue=RegGetValue -Key $Key -Value *SpeedDuplex -GetValue GetStringValue -ErrorAction SilentlyContinue     
        if ($SpeedDuplexValue -ne $null)
        {
            $SpeedDuplex=GetSpeedDuplexFromValue -SV $([int]$SpeedDuplexValue)
        }
        $AdapterTypeValue=RegGetValue -Key $Key -Value *MediaType -GetValue GetDWORDValue -ErrorAction SilentlyContinue
        if ($AdapterTypeValue -ne $null)
        {
            $AdapterType=GetAdapterTypeFromValue -SV $([int]$AdapterTypeValue)
        } 
	$DriverVersion=RegGetValue -key $Key -Value DriverVersion -GetValue GetStringValue -ErrorAction SilentlyContinue
    
    }
    
    $Status=GetStatusFromValue -Sv $Adapter.NetConnectionStatus
    
    
    
    $TmpObject=New-Object -TypeName psobject
    $TmpObject | Add-Member -MemberType NoteProperty -Name Index -Value $Adapter.deviceid
    $TmpObject | Add-Member -MemberType NoteProperty -Name Name -Value $Adapter.Name
    $TmpObject | Add-Member -MemberType NoteProperty -Name NetConnectionID -Value $Adapter.NetConnectionID
    $TmpObject | Add-Member -MemberType NoteProperty -Name MediaType -Value $AdapterType
    $TmpObject | Add-Member -MemberType NoteProperty -Name Status -Value $Status
    $TmpObject | Add-Member -MemberType NoteProperty -Name MACAddress -Value $Adapter.MACAddress
	$TmpObject | Add-Member -MemberType NoteProperty -Name DriverVersion -Value $([version]$DriverVersion)
    $TmpObject | Add-Member -MemberType NoteProperty -Name SpeedDuplex -Value $SpeedDuplex
    $TmpObject | Add-Member -MemberType NoteProperty -Name SpeedMbps -Value $LinkSpeed
    $AdaptersHashTable.Add("$($Adapter.deviceid)",$TmpObject) 
    #$TmpObject
    
}

$Win32_NetworkAdapterConfiguration | foreach {
    if ($($_.MACAddress -or $_.IPAddress -or $_.DHCPServer -or $_.DefaultIPGateway -or $_.DNSServerSearchOrder) )
    {
        
        $AdapterObject=$AdaptersHashTable["$($_.index)"]         
        $AdapterObject | Add-Member -MemberType NoteProperty -Name DHCPEnabled -Value $_.DHCPEnabled
        $AdapterObject | Add-Member -MemberType NoteProperty -Name DHCPServer -Value $_.DHCPServer
        $AdapterObject | Add-Member -MemberType NoteProperty -Name IPAddress -Value $_.IPAddress
        $AdapterObject | Add-Member -MemberType NoteProperty -Name DefaultIPGateway -Value $_.DefaultIPGateway
        $AdapterObject | Add-Member -MemberType NoteProperty -Name DNSServerSearchOrder -Value $_.DNSServerSearchOrder
        if ($AdapterObject.name -ne "RAS Async Adapter")
        {
            $AdapterObject
        }
        
    }
}
