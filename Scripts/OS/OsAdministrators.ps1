try{
    $LangAdminGroups=@{
    #Key Microsoft Locale ID Values https://msdn.microsoft.com/ru-ru/library/ms912047(v=winembedded.10).aspx, Value Administrators Group
    "1049"="Администраторы"
    "1033"="Administrators"
    }
    $ComputerName=$Win32_OperatingSystem.__SERVER
    $GroupName=$LangAdminGroups["$($Win32_OperatingSystem.OSLanguage)"]
    if ($GroupName -eq $Null)
    {
        $GroupName="Administrators"
    }
    if ($Credential)
    {
        $wmitmp = Get-WmiObject -ComputerName $ComputerName -Query "SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`"" -ErrorAction Stop -Credential $Credential
    }
    else
    {
        $wmitmp = Get-WmiObject -ComputerName $ComputerName -Query "SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`"" -ErrorAction Stop
    }

    if ($wmitmp -ne $null)  
    {  
        $DispObjArray=@()
        $wmitmp | foreach{   
            if ($_.PartComponent -match '(.+:)?(.+)\..+?="(.+?)",Name="(.+?)"')
            {
            $Type=$Matches[2]
            $Domain=$matches[3]
            $Name=$Matches[4]
                if ($domain -eq $computername)
                {
                    $IsLocalAccount=$True
                }
                else
                {
                    $IsLocalAccount=$false
                }
                    
            $DispObj=New-Object psobject 
            $DispObj | Add-Member -MemberType NoteProperty -Name FullName -Value "$Domain\$Name"
            #$DispObj | Add-Member -MemberType NoteProperty -Name Domain -Value $Domain
            #$DispObj | Add-Member -MemberType NoteProperty -Name Name -Value $Name
            $DispObj | Add-Member -MemberType NoteProperty -Name Type -Value $Type
            $DispObj | Add-Member -MemberType NoteProperty -Name IsLocal -Value $IsLocalAccount
            $DispObjArray+=$DispObj 
            }
                
        }  
        $DispObjArray | Sort-Object -Property IsLocal,Type
    } 
    else
    {
        Write-Error -Message "Query SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`" return null value. Check LangAdminGroups hashtable in OsAdministrators.ps1" -ErrorAction Stop
    } 
}
catch
{
    Write-Error $_
}