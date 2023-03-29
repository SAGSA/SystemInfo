#$Win32_bios = Get-WmiObject -Class win32_bios
$Res=New-Object -TypeName psobject
$Res | Add-Member -MemberType NoteProperty -Name Manufacturer -Value $Win32_bios.Manufacturer
$Res | Add-Member -MemberType NoteProperty -Name Version -Value $Win32_bios.SMBIOSBIOSVersion
$Res | Add-Member -MemberType NoteProperty -Name ReleaseDate -Value $Win32_bios.ReleaseDate
$Res