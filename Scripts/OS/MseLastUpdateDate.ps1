#$stdregprov=Get-WmiObject -Class stdregprov -List
#$win32_operatingsystem=Get-WmiObject -Class win32_operatingsystem
#$Computername="Localhost"
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
        $AvName = $AntiVirusProduct.displayName; 
        if ($AvName -match "^Microsoft")
        {
            $ARegKey="HKEY_LOCAL_MACHINE\Software\Microsoft\Microsoft Antimalware\Signature Updates"
        }
        elseif($AvName -match "^Windows")
        {
            $ARegKey="HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Signature Updates"
        }
        else
        {
            Write-Error "MSE not found" -ErrorAction Stop
        }
        $BinData=RegGetValue -Key $ARegKey -Value SignaturesLastUpdated -GetValue GetBinaryValue -ErrorAction Stop
        $SigLastUpd = [DateTime]::FromFileTime( (((((($BinData[7]*256 + $BinData[6])*256 + $BinData[5])*256 + $BinData[4])*256 + $BinData[3])*256 + $BinData[2])*256 + $BinData[1])*256 + $BinData[0])
        $SigLastUpd
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