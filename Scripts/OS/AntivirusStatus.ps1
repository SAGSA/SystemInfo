Try 
{ 
    if ($win32_operatingsystem.producttype -eq 1)
    {
        [system.Version]$OSVersion = $win32_operatingsystem.version 
 
        if ($Credential)
        {
            IF ($OSVersion -ge [system.version]'6.0.0.0')  
            { 
                $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ComputerName $Computername -ErrorAction Stop -Credential $Credential 
            }  
            Else  
            {   
                $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter -Class AntiVirusProduct  -ComputerName $Computername -ErrorAction Stop -Credential $Credential 
            } # end IF 
    
        }
        else
        {
            IF ($OSVersion -ge [system.version]'6.0.0.0')  
            { 
                $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ComputerName $Computername -ErrorAction Stop 
            }  
            Else  
            {   
                $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter -Class AntiVirusProduct  -ComputerName $Computername -ErrorAction Stop 
            } # end IF 
        }
    
        $productState = $AntiVirusProduct.productState 
 
        # convert to hex, add an additional '0' left if necesarry 
        $hex = [Convert]::ToString($productState, 16).PadLeft(6,'0') 
 
        # Substring(int startIndex, int length)   
        $WSC_SECURITY_PRODUCT_STATE = $hex.Substring(2,2) 
        $WSC_SECURITY_SIGNATURE_STATUS = $hex.Substring(4,2) 
    
        $RealTimeProtectionStatus = switch ($WSC_SECURITY_PRODUCT_STATE) 
        { 
            "00" {"OFF"}  
            "01" {"EXPIRED"} 
            "10" {"ON"} 
            "11" {"SNOOZED"} 
            default {"UNKNOWN"} 
        } 
 
        $DefinitionStatus = switch ($WSC_SECURITY_SIGNATURE_STATUS) 
        { 
            "00" {"Updated"} 
            "10" {"NotUpdated"} 
            default {"UNKNOWN"} 
        }                  
        # Output PSCustom Object 
        $Object = New-Object -TypeName PSObject -ErrorAction Stop -Property @{  
            Name = $AntiVirusProduct.displayName; 
            Definition = $DefinitionStatus; 
            RealTimeProtection = $RealTimeProtectionStatus; 
                 
        } | Select-Object Name,Definition,RealTimeProtection  
                 
        $Object 
    }
    else
    {
        Write-Error "NotSupported" -ErrorAction Stop
    }
    
} 
Catch  
{ 
    write-error $_ 
}                               
        
        
   
 
