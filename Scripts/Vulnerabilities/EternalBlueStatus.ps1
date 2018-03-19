try
{
#https://support.microsoft.com/en-us/help/4023262/how-to-verify-that-ms17-010-is-installed
    
    $OsVerFileVer=@{
    #Windows XP
    "5.1.2600"="5.1.2600.7208"
    #Windows Server 2003 SP2
    "5.2.3790"="5.2.3790.6021"
    #Windows 7 Windows Server 2008 R2
    "6.1.7601"="6.1.7601.23689"
    #Windows 8 Windows Server 2012
    "6.2.9200"="6.2.9200.22099"
    #Windows 8.1 Windows Server 2012 R2
    "6.3.9600"="6.3.9600.18604"
    #Windows 10 TH1 v1507
    "10.0.10240"="10.0.10240.17319"
    #Windows 10 TH2 v1511
    "10.0.10586"="10.0.10586.839"
    #Windows 10 RS1 v1607 Windows Server 2016
    "10.0.14393"="10.0.14393.953"
    }
    $Status="NotPatched"
    $OsVersion=$Win32_OperatingSystem.version
    $MinimumFileVersion=$OsVerFileVer[$OsVersion]
    $SystemDir=$Win32_OperatingSystem.SystemDirectory
    $File=$SystemDir+"\drivers\srv.sys"
    $filewmi=$file -replace "\\","\\"
    if ($Credential)
    {
        $SrvSysVer=(Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$filewmi'" -ComputerName $Computername -Credential $Credential -ErrorAction Stop).version
    }
    else
    {
        $SrvSysVer=(Get-WmiObject -Class CIM_DataFile -namespace "root\cimv2" -Filter "Name='$filewmi'" -ComputerName $Computername -ErrorAction Stop).version
    }
    
    if ($OsVersion -eq "5.1.2600")
    {
        if ($SrvSysVer -match ".+\s")
        {
            $SrvSysVer=$Matches[0]
        }
  
    }
    
    if ([version]$OsVersion -ge [Version]"10.0.14393") 
    {
        $Status="NotRequired"   
    }
    else
    {
        if ($MinimumFileVersion -ne $null)
        {
            if ([version]$SrvSysVer -ge [version]$MinimumFileVersion)
            {
                $Status="Patched"
            }
        }
        else
        {
            Write-Warning "$Computername Unknown OS version. Check OsVerFileVer hashtable"
        }
    }
    
    $smb1Protocol = RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Value "SMB1" -GetValue GetDWORDValue -ErrorAction SilentlyContinue 
    
    if ($smb1Protocol -eq 0) 
    {
        $smb1ProtocolDisabled = $True
    } 
    else 
    {
        $smb1ProtocolDisabled = $false
    }   
    $PsObject=New-Object -TypeName psobject
    $PsObject | Add-Member -MemberType NoteProperty -Name SrvSysVersion -Value $SrvSysVer
    $PsObject | Add-Member -MemberType NoteProperty -Name Smb1ProtocolDisabled -Value $smb1ProtocolDisabled
    $PsObject | Add-Member -MemberType NoteProperty -Name Status -Value $Status
    $PsObject
}
catch
{
    Write-Error $_
}
