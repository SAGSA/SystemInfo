#$stdregProv = Get-Wmiobject -list "StdRegProv" -namespace root\default
function RegGetValue
{
[CmdletBinding()]
param(
[parameter(Mandatory=$true)]
[string]$Key,
[parameter(Mandatory=$true)]
[string]$Value,
[parameter(Mandatory=$true)]
[ValidateSet("GetStringValue","GetBinaryValue","GetDWORDValue","GetQWORDValue","GetMultiStringValue")]
[string]$GetValue
)
if ($stdregprov -eq $null)
{
    Write-Error "Variable StdRegProv Null"
}
$ResultProp=@{
"GetStringValue"="Svalue"
"GetBinaryValue"="Uvalue"
"GetDWORDValue"="UValue"
"GetQWORDValue"="UValue"
"GetMultiStringValue"="Svalue"
}
$ErrorCode=@{
"1"="Value doesn't exist"
"2"="Key doesn't exist"
"2147749893"="Wrong value type"
"5"="Access Denied"
"6"="Wrong Key String"
}
$hk=@{

"HKEY_CLASSES_ROOT"=2147483648
"HKEY_CURRENT_USER"=2147483649
"HKEY_LOCAL_MACHINE"=2147483650
"HKEY_USERS"=2147483651
"HKEY_CURRENT_CONFIG"=2147483653

}
if($Key -match "(.+?)\\(.+)")
{
    if ($hk.Keys -eq $matches[1])
    {
        $RootHive=$hk[$matches[1]]
        $KeyString=$matches[2]
        $StdRegProvResult=$StdRegProv | Invoke-WmiMethod -Name $GetValue -ArgumentList $RootHive,$KeyString,$Value
    }
    else
    {
        Write-Error "$($matches[1]) Does not belong to the set $($hk.Keys)" -ErrorAction Stop
    }
    if ($StdRegProvResult.returnvalue -ne 0)
    {
        if ($ErrorCode["$($StdRegProvResult.returnvalue)"] -ne $null)
        {
            $er=$ErrorCode["$($StdRegProvResult.returnvalue)"]
            Write-Error "$Er! Key $Key Value $Value "
        }
        else
        {
            $er=$StdRegProvResult.returnvalue
            Write-Error "$GetValue return $Er! Key $Key Value $Value "
        }
        
    }
    else
    {
        $StdRegProvResult.($ResultProp["$GetValue"])
    }
}
else
{
    Write-Error "$Key not valid"
}

}
function RegEnumKey
{
[CmdletBinding()]
param(
[parameter(Mandatory=$true)]
[string]$Key
)
$ErrorActionPreference="Stop"
if ($stdregprov -eq $null)
{
    Write-Error "Variable StdRegProv Null"
}
$ErrorCode=@{
"1"="Value doesn't exist"
"2"="Key doesn't exist"
"5"="Access Denied"
"6"="Wrong Key String"
}
$hk=@{

"HKEY_CLASSES_ROOT"=2147483648
"HKEY_CURRENT_USER"=2147483649
"HKEY_LOCAL_MACHINE"=2147483650
"HKEY_USERS"=2147483651
"HKEY_CURRENT_CONFIG"=2147483653
}
if($Key -match "(.+?)\\(.+)")
{
$StdRegProvResult=$StdRegProv.EnumKey($hk[$matches[1]],$matches[2])
    if ($StdRegProvResult.returnvalue -ne 0)
    {
        if ($ErrorCode["$($StdRegProvResult.returnvalue)"] -ne $null)
        {
            $er=$ErrorCode["$($StdRegProvResult.returnvalue)"]
        }
        else
        {
            $er=$StdRegProvResult.returnvalue
        }
    Write-Error "$Er key $Key"
        
    }
    else
    {
        $StdRegProvResult.snames
    }
}
else
{
    Write-Error "$Key not valid"
}

}

function RegEnumValues
{
[CmdletBinding()]
param(
[parameter(Mandatory=$true)]
[string]$Key
)
$ErrorActionPreference="Stop"
if ($stdregprov -eq $null)
{
    Write-Error "Variable StdRegProv Null"
}
$ErrorCode=@{
"1"="Value doesn't exist"
"2"="Key doesn't exist"
"5"="Access Denied"
"6"="Wrong Key String"
}
$hk=@{

"HKEY_CLASSES_ROOT"=2147483648
"HKEY_CURRENT_USER"=2147483649
"HKEY_LOCAL_MACHINE"=2147483650
"HKEY_USERS"=2147483651
"HKEY_CURRENT_CONFIG"=2147483653
}
if($Key -match "(.+?)\\(.+)")
{
$StdRegProvResult=$StdRegProv.EnumValues($hk[$matches[1]],$matches[2])
    if ($StdRegProvResult.returnvalue -ne 0)
    {
        if ($ErrorCode["$($StdRegProvResult.returnvalue)"] -ne $null)
        {
            $er=$ErrorCode["$($StdRegProvResult.returnvalue)"]
        }
        else
        {
            $er=$StdRegProvResult.returnvalue
        }
    Write-Error "$Er key $Key"
        
    }
    else
    {
        $StdRegProvResult.snames
    }
}
else
{
    Write-Error "$Key not valid"
}

}
function GetServiceInfo
{
    [cmdletbinding()]
    param([array]$MatchBinPath)
    try
    {
        function GetServiceFromRegistry
        {
                param([string]$RootKey,[array]$SubKeys,[string]$MatchBinPath)
                function CreateServiceInfo
                {
                    $CommandLine =RegGetValue -key $ChildPath -Value "ImagePath" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                    $DisplayName=RegGetValue -key $ChildPath -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                    if ($CommandLine -match "(.+\.exe)")
                    {
                        $ImagePath=$Matches[1]
                    }
                    else
                    {
                        $ImagePath=$CommandLine
                    }
                    $TmpObject= New-Object psobject
                    $TmpObject | Add-Member -MemberType NoteProperty -Name DisplayName -Value $DisplayName
                    $TmpObject | Add-Member -MemberType NoteProperty -Name ImagePath -Value $ImagePath
                    $TmpObject | Add-Member -MemberType NoteProperty -Name CommandLine -Value  $CommandLine
                    $TmpObject  
                }
                $SubKeys | foreach {
                    $ChildPath=Join-Path -Path $RootKey -ChildPath $_      
                    $ImagePath=$null
                    $ImagePath =RegGetValue -key $ChildPath -Value "ImagePath" -GetValue GetStringValue -ErrorAction SilentlyContinue -Verbose:$false
                    if ($ImagePath -ne $null)
                    {
                        if ($PSBoundParameters["MatchBinPath"] -ne $null)
                        {
                            if ($ImagePath -match $MatchBinPath)
                            {
                                CreateServiceInfo
                            }
                            else
                            {
                                #Write-Verbose "Skip $ImagePath"
                            }      
                        }
                        else
                        {
                            CreateServiceInfo  
                        }
                    }
                    else
                    {
                        #Write-Verbose "$Computername $ChildPath Value ImagePath is Null"
                    }
                }
        }
    
        $AllServices=@()
        $ServiceRootKey="HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services"
        [array]$SubKeys=RegEnumKey -key $ServiceRootKey
        if ($PSBoundParameters["MatchBinPath"] -ne $null)
        {
            $AllServices+=GetServiceFromRegistry -RootKey $ServiceRootKey -SubKeys $SubKeys  -MatchBinPath $MatchBinPath
        }
        else
        {
            $AllServices+=GetServiceFromRegistry -RootKey $ServiceRootKey -SubKeys $SubKeys
        }
        if ($AllServices.count -ne 0)
        {
            $AllServices
        }
        else
        {
            Write-Error "not found $MatchBinPath"
        }
    }
    catch
    {
        Write-Error $_
    }
    
}