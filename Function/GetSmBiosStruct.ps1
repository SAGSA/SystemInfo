function GetSmbiosStruct
{
[cmdletbinding()]
param(
[parameter(Mandatory=$true)]
[int]$Type,
[parameter(Mandatory=$true)]
[string]$Offset,
[parameter(Mandatory=$true)]
[ValidateSet("String","Other")]
$Value
)
    function ConvertToHex ( $DEC ) 
    {
	    '{0:x2}' -f [int]$DEC
    }
    function ConvertToDec ( $HEX ) 
    {
        [Convert]::ToInt32( $HEX, 16 )
    }    

    if ($Offset -match "(.+)h$")
    {
        [string]$OffsetHexValue=$Matches[1]    
        [int]$OffsetDecValue=ConvertToDec -HEX $OffsetHexValue
    }
    else
    {
        Write-Error "Unknown offset.."
    }
  
    if ($MSSMBios_RawSMBiosTables -eq $null)
    {
        if ($Computername -eq $null)
        {
            $Computername=$env:COMPUTERNAME
        }
        if ($credential)
        {
            $MSSMBiosData = (Get-WmiObject -Class MSSMBios_RawSMBiosTables -Namespace root\wmi -ComputerName $Computername -Credential $credential -ErrorAction SilentlyContinue).SMBiosData
        }
        else
        {
            $MSSMBiosData = (Get-WmiObject -Class MSSMBios_RawSMBiosTables -Namespace root\wmi -ComputerName $Computername -ErrorAction SilentlyContinue).SMBiosData
        }
        
    }
    else
    {
        $MSSMBiosData=$MSSMBios_RawSMBiosTables | foreach {$_.SmBiosData}    
    }
    
    if ($MSSMBiosData -ne $null)
    {
        $i = 0
        $Struct=$null
        while (($MSSMBiosData[$i+1] -ne $null) -and ($MSSMBiosData[$i+1] -ne 0)) 
        { 
            # While the structure has non-0 length
            $i0 = $i
            $n = $MSSMBiosData[$i]   # Structure type
            $l = $MSSMBiosData[$i+1] # Structure length
            #Write-Verbose "Skipping structure $n body"
            $i += $l # Skip the structure body
            if ($MSSMBiosData[$i] -eq 0) {$i++} # If there's no trailing string, skip the extra NUL
            while ($MSSMBiosData[$i] -ne 0) 
            { # And skip the trailing strings
                $s = ""
                while ($MSSMBiosData[$i] -ne 0) 
                { 
                $s += [char]$MSSMBiosData[$i++] 
                }
                #Write-Verbose "Skipping string $s"
                $i++ # Skip the string terminator NUL
            }
            $i1 = $i
            $i++ # Skip the string list terminator NUL
            if ($n -eq $Type) 
            {
                $Struct=$MSSMBiosData[$i0..$i1]
            }

        }
        if ($Struct -ne $null)
        {
   
            if ($Value -eq "String")
            {
                $StringIndex=$Struct[$OffsetDecValue]
        
                if ($StringIndex -ne 0)
                {
                    $i=$Struct[1]
                    $CountIndex=0
                    while ($Struct[$i] -ne 0) 
                    {
                        $retry=$true
                        $CountIndex++
                        $s = ""
                        while ($Struct[$i] -ne 0) 
                        { 
                            $s += [char]$Struct[$i++] 
                        }
                        Write-Verbose "Skipping string $s"
                        $i++ # Skip the string terminator NUL
                        if($CountIndex -eq $StringIndex)
                        {
                            $String=$s
                        }
                    }
                    $String
                }
                else
                {
                    Write-Verbose "Empty string" -Verbose
                }
        
            }
            else
            {
                $Struct[$OffsetDecValue]    
            }
    
        }
        else
        {
            Write-Error "Unknown Type $type"   
        }
    }
}



    
  



