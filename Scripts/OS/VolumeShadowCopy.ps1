try
{
    function GetDriveLetter
    {
        Param([string]$VolumeID)
        ($Win32_Volume | Where-Object {$_.deviceid -eq $VolumeID }).driveletter    
    }
    if ($Win32_ShadowCopy)
    {
        $Win32_ShadowCopy | foreach {
        $Psobject=New-Object -TypeName psobject
        $InstallDate=$_.ConvertToDateTime($_.InstallDate)
        $Psobject | Add-Member -MemberType NoteProperty -Name InstallDate -Value $InstallDate
        $DrLetter=GetDriveLetter -VolumeID $_.volumename
        $Psobject| Add-Member -MemberType NoteProperty -Name Drive -Value $DrLetter
        $Psobject| Add-Member -MemberType NoteProperty -Name ID -Value $_.ID
        $Psobject
        }
    
    }
    else
    {
        "NoShadowCopies"
    }
    
}
catch
{
    Write-Error $_
}


