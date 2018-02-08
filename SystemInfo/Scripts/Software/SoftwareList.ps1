try{
$Object =@()
$excludeArray = ("Security Update for Windows",
"Update for Windows",
"Update for Microsoft .NET",
"Security Update for Microsoft",
"Hotfix for Windows",
"Hotfix for Microsoft .NET Framework",
"Hotfix for Microsoft Visual Studio 2007 Tools",
"Hotfix",
"Update for Microsoft Office"
)

$GetArch=RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "PROCESSOR_ARCHITECTURE" -GetValue GetStringValue -ErrorAction Stop 
If($GetArch -eq "AMD64")
{            
    $OSArch='64-bit'
}            
Else
{            
    $OSArch='32-bit'            
}
Switch ($OSArch)
{


 "64-bit"{

$RegKey_64BitApps_64BitOS = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$RegKey_32BitApps_64BitOS = "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
#$RegKey_32BitApps_32BitOS = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"

#############################################################################

# Get SubKey names

$SubKeys = RegEnumKey -key $RegKey_64BitApps_64BitOS -ErrorAction Stop



ForEach ($Name in $SubKeys)
 {

$SubKey = "$RegKey_64BitApps_64BitOS\$Name"

$AppName = RegGetValue -key $SubKey -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Version =RegGetValue -key $SubKey -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Publisher=RegGetValue -key $SubKey -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue
$donotwrite = $false

if($AppName.length -gt "0"){

 Foreach($exclude in $excludeArray) 
    {
        if($AppName.StartsWith($exclude) -eq $TRUE)
        {
            $donotwrite = $true
            break
        }
    }
            if ($donotwrite -eq $false) 
                        {                        
                        $TmpObject="" | Select-Object Appication,Architecture,Version,Publisher
                        $TmpObject.Appication=$AppName
                        $TmpObject.Architecture="64-BIT"
                        $TmpObject.Version=$Version
                        $TmpObject.Publisher=$Publisher
                        $Object += $TmpObject
                        }





}

  }

 

#############################################################################
$SubKeys = RegEnumKey -key $RegKey_32BitApps_64BitOS -ErrorAction Stop

  # Loop Through All Returned SubKEys

  ForEach ($Name in $SubKeys)

  {

    $SubKey = "$RegKey_32BitApps_64BitOS\$Name"

$AppName = RegGetValue -key $SubKey -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Version =RegGetValue -key $SubKey -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Publisher=RegGetValue -key $SubKey -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue

 $donotwrite = $false
         
                             



if($AppName.length -gt "0"){
 Foreach($exclude in $excludeArray) 
                        {
                        if($AppName.StartsWith($exclude) -eq $TRUE)
                            {
                            $donotwrite = $true
                            break
                            }
                        }
            if ($donotwrite -eq $false) 
                        {                        
            $TmpObject="" | Select-Object Appication,Architecture,Version,Publisher
            $TmpObject.Appication=$AppName
            $TmpObject.Architecture="32-BIT"
            $TmpObject.Version=$Version
            $TmpObject.Publisher=$Publisher
            $Object += $TmpObject
                        }
           }

 

    }

 



 

} #End of 64 Bit

######################################################################################

###########################################################################################

 

"32-bit"{

$RegKey_32BitApps_32BitOS = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"

#############################################################################

# Get SubKey names

$SubKeys = RegEnumKey -key $RegKey_32BitApps_32BitOS -ErrorAction Stop
# Loop Through All Returned SubKEys
ForEach ($Name in $SubKeys)

  {
$SubKey = "$RegKey_32BitApps_32BitOS\$Name"
$AppName = RegGetValue -key $SubKey -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Version =RegGetValue -key $SubKey -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Publisher=RegGetValue -key $SubKey -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue

if($AppName.length -gt "0"){

$TmpObject="" | Select-Object Appication,Architecture,Version,Publisher
$TmpObject.Appication=$AppName
$TmpObject.Architecture="32-BIT"
$TmpObject.Version=$Version
$TmpObject.Publisher=$Publisher

$Object+= $TmpObject
           }

  }

}#End of 32 bit

} # End of Switch

$object 
}
catch
    {
    $_
    }