try
{  
    #To exclude from the output software starting with
    $MatchExcludeSoftware = @(
    "Security Update for Windows",
    "Update for Windows",
    "Update for Microsoft",
    "Security Update for Microsoft",
    "Hotfix",
    "Update for Microsoft Office",
    " Update for Microsoft Office"
    )
    function GetSoftwareFromRegistry
    {
    param([string]$RootKey,[array]$SubKeys,[string]$DisplayOSArch)
        $SubKeys | foreach {
            $ChildPath=Join-Path -Path $RootKey -ChildPath $_      
            $AppName=$null
            $AppName = RegGetValue -key $ChildPath -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
            if ($AppName -ne $null)
            {
                $Version =RegGetValue -key $ChildPath -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
                $Publisher=RegGetValue -key $ChildPath -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue
                #$UninstallString=RegGetValue -key $ChildPath -Value "UninstallString" -GetValue GetStringValue -ErrorAction SilentlyContinue
                $TmpObject="" | Select-Object Name,Architecture,Version,Publisher
                $TmpObject.Name=$AppName
                $TmpObject.Architecture=$DisplayOSArch
                $TmpObject.Version=$Version
                $TmpObject.Publisher=$Publisher
                #$TmpObject.UninstallString=$UninstallString
                $TmpObject
            }
            else
            {
                Write-Verbose "$Computername $ChildPath Value DisplayName is Null"
            }
        }
    }
    $GetArch=RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "PROCESSOR_ARCHITECTURE" -GetValue GetStringValue -ErrorAction Stop
    If($GetArch -eq "AMD64")
    {            
        $OSArch='64-bit'
    }            
    Else
    {            
        $OSArch='32-bit'            
    }
    $AllSoftWare=@()
    if ($OSArch -eq "64-bit")
    {
        $RootUninstallKeyX64="HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"  
        [array]$SubKeysX64=RegEnumKey -key $RootUninstallKeyX64
        $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKeyX64 -SubKeys $SubKeysX64 -DisplayOSArch "32-bit"
    }

    $RootUninstallKey="HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    [array]$SubKeys=RegEnumKey -key $RootUninstallKey
    $AllSoftWare+=GetSoftwareFromRegistry -RootKey $RootUninstallKey -SubKeys $SubKeys -DisplayOSArch $OSArch
    
    $AllSoftWare | Sort-Object {$_.Name} -Unique | foreach {
        $ReturnSoftware=$True
        $Software=$_
        $MatchExcludeSoftware | foreach {
            if ($Software.name -match "^$_")
            {
               $ReturnSoftware=$false
            }
        }
        if ($ReturnSoftware)
        {
            $Software
        }
    }
}
catch
{
    Write-Error $_
}
