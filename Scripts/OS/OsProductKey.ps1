try
{
    $map="BCDFGHJKMPQRTVWXY2346789" 
    If((RegGetValue -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "PROCESSOR_ARCHITECTURE" -GetValue GetStringValue -ErrorAction Stop) -eq "AMD64")
    {            
        $value=(RegGetValue -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Value "DigitalProductId4" -GetValue GetBinaryValue -ErrorAction Stop)[0x34..0x42]
    }            
    Else
    {            
        $value=(RegGetValue -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Value "DigitalProductId" -GetValue GetBinaryValue -ErrorAction Stop)[0x34..0x42]       
    }

    $ProductKey = ""  
                    
                        for ($i = 24; $i -ge 0; $i--) { 
                          $r = 0 
                          for ($j = 14; $j -ge 0; $j--) { 
                            $r = ($r * 256) -bxor $value[$j] 
                            $value[$j] = [math]::Floor([double]($r/24)) 
                            $r = $r % 24 
                          } 
                          $ProductKey = $map[$r] + $ProductKey 
                          if (($i % 5) -eq 0 -and $i -ne 0) { 
                            $ProductKey = "-" + $ProductKey 
                          } 
                        }
                 
    $ProductKey
}
catch
{
    write-error $_
}