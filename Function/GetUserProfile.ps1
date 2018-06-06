#$Computername=$env:COMPUTERNAME
#$Win32_UserProfile=Get-WmiObject -Class Win32_UserProfile -Namespace root\cimv2 -ComputerName $Computername
function GetUserProfile
{
[CmdletBinding()]
param(
[switch]$OnlyLoaded
)
try
{
    if ($win32_userprofile -eq $null)
    {
        Write-Error "Variable Win32_UserProfile is null" -ErrorAction Stop
    }
    $AllUserProfiles=@()
    [string[]]$ExcludeSid="S-1-5-18","S-1-5-19","S-1-5-20"
    if ($credential)
    {
        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true" -Credential $credential
    }
    else
    {
        $LocalAccount=Get-WmiObject -Class Win32_UserAccount -ComputerName $Computername -Filter "LocalAccount=$true"
    }
    if ($PSBoundParameters["OnlyLoaded"].IsPresent)
    {
        $Win32UserProfiles=$Win32_UserProfile | Where-Object {!($ExcludeSid -eq $_.sid) -and $_.loaded} 
        if ($Win32UserProfiles -eq $null)
        {
            Write-Error "User profile is not loaded"
        }
    }
    else
    {
        $Win32UserProfiles=$Win32_UserProfile | Where-Object {!($ExcludeSid -eq $_.sid)} 
    }
    
    $Win32UserProfiles | Select-Object -Property * | foreach {
        $Sid=$_.sid
        $LastUseTime=$null
        $User=$null
        $ProfileDirectory=$null
        $LocalPath=$_.localpath
        $objSID = New-Object System.Security.Principal.SecurityIdentifier($Sid) 
        try
        {
            $objUser = $objSID.Translate([System.Security.Principal.NTAccount])
            $User=$objUser.Value
            Write-Verbose "$Computername Translate sid $sid succesfully"
        }
        catch
        {
            Write-Verbose "$Computername Unknown sid $sid"
            $User=($LocalAccount | Where-Object {$_.sid -eq $Sid}).caption
            if ($User -eq $null)
            {
                $User="Unknown"
            }
        }
       
       $_ | Add-Member -MemberType NoteProperty -Name User -Value $User
       $_
    } | Select-Object -Property User,SID,LocalPath,Loaded | foreach {$AllUserProfiles+=$_}    
$AllUserProfiles
}
catch
{
    Write-Error $_
}

}

