$ActStat=@{
"1"  = "Licensed"
"2"  = "Out-Of-Box Grace Period"
"3"  = "Out-Of-Tolerance Grace Period"
"4"  = "Non-Genuine Grace Period"
"5"  = "Notification"
"6"  = "Extended Grace"
}

if ($Query_SoftwareLicensingProduct_OsActivationStatus)
{
$LicStat=($Query_SoftwareLicensingProduct_OsActivationStatus.Licensestatus).tostring()
$Stat=$ActStat[$LicStat]
    if (!$Stat)
    {
        $Stat="Unknown value $($Query_SoftwareLicensingProduct_OsActivationStatus.Licensestatus)"
    }
    if ($Query_SoftwareLicensingProduct_OsActivationStatus.Description -match ".+,\s?(.+)")
    {
        $Descr=$Matches[1]
    }
    else
    {
        $Query_SoftwareLicensingProduct_OsActivationStatus.Description
    }
    
$KmsPort=$Query_SoftwareLicensingProduct_OsActivationStatus.KeyManagementServicePort
$KmsServer=$Query_SoftwareLicensingProduct_OsActivationStatus.KeyManagementServiceMachine
    if ($KmsServer -and $KmsPort)
    {
        $FullKms=$KmsServer+":"+$KmsPort
    }
    else
    {
        $FullKms=$null
    }
    
}
else
{
    $Stat="Unlicensed or Unknown"
}
$Prop=@{
    "Status"=$Stat
    "Description"=$Descr
}
if ($FullKms)
{
    $Prop.Add("KMSServer",$FullKms)
}
$DispObj=New-Object psobject -Property $Prop
$DispObj