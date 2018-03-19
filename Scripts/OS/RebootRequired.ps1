try
{

<#
Component-Based Servicing 
    http://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx
PendingFileRename/Auto Update:
    http://support.microsoft.com/kb/2723674
    http://technet.microsoft.com/en-us/library/cc960241.aspx
    http://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx
#>
    $OsBuild=$Win32_OperatingSystem.BuildNumber

    $CompPendRen,$PendFileRename,$Pending = $false,$false,$false

    ## If Vista/2008 & Above query the CBS Reg Key
    If ([Int32]$OsBuild -ge 6001) 
    {
        $RegSubKeysCBS=RegEnumKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing"
        $CBSRebootPend = $RegSubKeysCBS -contains "RebootPending"		
    }

    ## Query WUAU from the registry
    $RegWUAURebootReq = RegEnumKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
    $WUAURebootReq = $RegWUAURebootReq -contains "RebootRequired"

    ## Query PendingFileRenameOperations from the registry
    $RegValuePFRO=RegGetValue -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager" -Value "PendingFileRenameOperations" -GetValue GetMultiStringValue -ErrorAction SilentlyContinue

    ## Query JoinDomain key from the registry - These keys are present if pending a reboot from a domain join operation
    $Netlogon=RegEnumKey -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Netlogon"
    $PendDomJoin = ($Netlogon -contains 'JoinDomain') -or ($Netlogon -contains 'AvoidSpnSet')

    ## Query ComputerName and ActiveComputerName from the registry
    $ActCompNm=RegGetValue -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -Value "ComputerName" -GetValue GetStringValue
    $CompNm = RegGetValue -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Value "ComputerName" -GetValue GetStringValue 

    If (($ActCompNm -ne $CompNm) -or $PendDomJoin) 
    {
        $CompPendRen = $true
    }
    If ($RegValuePFRO) 
    {
        $PendFileRename = $true
    }
    $PsObject=New-Object -TypeName PSObject
    $PsObject | Add-Member -MemberType NoteProperty -Name CBServicing -Value $CBSRebootPend
    $PsObject | Add-Member -MemberType NoteProperty -Name WindowsUpdate -Value $WUAURebootReq
    $PsObject | Add-Member -MemberType NoteProperty -Name ComputerRename -Value $CompPendRen
    $PsObject | Add-Member -MemberType NoteProperty -Name FileRename -Value $PendFileRename
    $PsObject | Add-Member -MemberType NoteProperty -Name RebootRequired -Value ($CompPendRen -or $CBSRebootPend -or $WUAURebootReq -or $PendFileRename)
    $PsObject

}
catch
{
    Write-Error $_
}
