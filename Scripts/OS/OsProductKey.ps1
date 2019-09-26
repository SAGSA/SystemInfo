#$stdregprov=Get-WmiObject -Class stdregprov -List
#$Computername="localhost"
function DecodeProductKeyData2($value)
{
    $map="BCDFGHJKMPQRTVWXY2346789"
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
function DecodeProductKeyData
{
#source https://github.com/mattcarras/Get-ProductKey/blob/master/Get-ProductKey.ps1			
param( 
				[Parameter(Mandatory = $true)]
				[byte[]]$BinaryValuePID 
			)
			Begin {
				# for decoding product key
				$KeyOffset = 52
				$CHARS="BCDFGHJKMPQRTVWXY2346789" # valid characters in product key
				$insert = 'N' # for Win8 or 10+
			} #end Begin
			Process {
				$ProductKey = ''
				$isWin8_or_10 = [math]::floor($BinaryValuePID[66] / 6) -band 1
				$BinaryValuePID[66] = ($BinaryValuePID[66] -band 0xF7) -bor (($isWin8_or_10 -band 2) * 4)
				for ( $i = 24; $i -ge 0; $i-- ) {
					$Cur = 0
					for ( $X = $KeyOffset+14; $X -ge $KeyOffset; $X-- ) {
						$Cur = $Cur * 256
						$Cur = $BinaryValuePID[$X] + $Cur
						$BinaryValuePID[$X] = [math]::Floor([double]($Cur/24))
						$Cur = $Cur % 24
					} #end for $X
					$ProductKey = $CHARS[$Cur] + $ProductKey
				} #end for $i
				If ( $isWin8_or_10 -eq 1 ) {
					$ProductKey = $ProductKey.Insert($Cur+1, $insert)
				}
				$ProductKey = $ProductKey.Substring(1)
				for ($i = 5; $i -le 26; $i += 6) {
					$ProductKey = $ProductKey.Insert($i, '-')
				}
				$ProductKey
			} #end Process
}
$Keys=@()
if ($credential)
{
    $PartialProductKey=(Get-WmiObject -Query "Select PartialProductKey From SoftwareLicensingProduct Where PartialProductKey is not null" -ComputerName $Computername -Credential $Credential).PartialProductKey 
}
else
{
    $PartialProductKey=(Get-WmiObject -Query "Select PartialProductKey From SoftwareLicensingProduct Where PartialProductKey is not null" -ComputerName $Computername).PartialProductKey
}

$Keys1Binary=(RegGetValue -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Value "DigitalProductId" -GetValue GetBinaryValue -ErrorAction SilentlyContinue)
$Keys2Binary=(RegGetValue -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Value "DefaultProductKey2" -GetValue GetBinaryValue -ErrorAction SilentlyContinue)
$Keys3Binary=(RegGetValue -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Value "DigitalProductId" -GetValue GetBinaryValue -ErrorAction SilentlyContinue)[0x34..0x42]
#$Keys+=(Get-WmiObject -Query "Select OA3xOriginalProductKey From SoftwareLicensingService Where OA3xOriginalProductKey is not null").OA3xOriginalProductKey

if ($Keys1Binary)
{
    $Keys+=DecodeProductKeyData -BinaryValuePID $Keys1Binary
}
if ($Keys2Binary)
{
    $Keys+=DecodeProductKeyData -BinaryValuePID $Keys2Binary
}
if ($Keys3Binary)
{
    $Keys+=DecodeProductKeyData2 -value $Keys3Binary   
}
if ($PartialProductKey)
{
    $Key=$Keys | Select-String -SimpleMatch $PartialProductKey
    if ($Key -eq $null)
    {
      Write-Error "Key not found"  
    }
    $Key.Line
}
else
{
    Write-Error "Key not found"
}
