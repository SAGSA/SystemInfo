$MemTypeWmi=@{
'0'='Unknown';
'1'='Other';
'2'='DRAM';
'4' ="Cache DRAM";
'5'='EDO';
'6'='EDRAM';
'7'='VRAM';
'8'='SRAM';
'9'='RAM';
'10'='ROM';
'11'='Flash';
'12'='EEPROM';
'13'='FEPROM';
'14'='EPROM';
'15'='CDRAM';
'16'='3DRAM';
'17'='SDRAM';
'18'='SGRAM';
'19'='RDRAM';
'20'='DDR';
'21'='DDR-2'
'22'='DDR2 FB-DIMM'
'24'='DDR3'
'25'='FBD2'
}
$MemTypeSmbios=@{
"1"= "Other"
"2"="Unknown"
"3"="DRAM"
"4"="EDRAM"
"5"="VRAM"
"6"="SRAM"
"7"="RAM"
"8"="ROM"
"9"="FLASH"
"10"="EEPROM"
"11"="FEPROM"
"12"="EPROM"
"13"="CDRAM"
"14"="3DRAM"
"15"="SDRAM"
"16"="SGRAM"
"17"="RDRAM"
"18"="DDR"
"19"="DDR2"
"20"="DDR2FB-DIMM"
"24"="DDR3"
"25"="FBD2"
"26"="DDR4"
"27"="LPDDR"
"28"="LPDDR2"
"29"="LPDDR3"
"30"="LPDDR4"
}

$MemTypeCpuIntel=@{
"94"="DDR4"
"158"="DDR4"
"58"="DDR3"
"42"="DDR3"
"15"="DDR2"
}

#$MemModules=$Win32_PhysicalMemory | Select-Object Capacity,MemoryType,Speed,Manufacturer,PartNumber
$MemModules=@()
$TypeWmi=@()
$Win32_PhysicalMemory | foreach {$TypeWmi+=$_.memorytype}
$TypeWmi=$TypeWmi[0]
$Smbios=$false
$MemoryType=$null
if ($TypeWmi -eq 0 -or $TypeWmi -eq 1)
{
    Write-Verbose "$Computername GetSmbiosStruct"
    $DecMemtype=GetSmbiosStruct -Type 17 -Offset 12h -Value Other -ErrorAction SilentlyContinue  
    Write-Verbose "DecMemtype $DecMemtype"
    if ($DecMemtype -ne 1 -and $DecMemtype -ne 2 -and $DecMemtype -ne $null)
    {
        $Smbios=$true
    }
    if (!$Smbios)
    {
        if ($win32_processor -eq $null)
        {
            if ($credential)
            {
                $win32_processor=Get-WmiObject -Class win32_processor -Namespace root\cimv2 -ComputerName $computername -Credential $credential -ErrorAction SilentlyContinue
            }
            else
            {
                Write-Verbose "$Computername Get-WmiObject -Class win32_processor"
                $win32_processor=Get-WmiObject -Class win32_processor -Namespace root\cimv2 -ComputerName $computername -ErrorAction SilentlyContinue
            }
            
        }
        if ($win32_processor -ne $null)
        {
            if ($Win32_Processor.Manufacturer -eq "GenuineIntel")
            {
                Write-Verbose "Intel Processor"
                $CpuDescript=$win32_processor.Description
                $Regex=[regex]'Family \d+ Model (\d+) Stepping \d+'
                $result = $regex.Match($CpuDescript)
                
                if ($result.Success)
                {
                    $Model=$result.Groups[1].Value
                    Write-Verbose "Model $model"
                    $MemoryType=$MemTypeCpuIntel["$Model"]
                }
            }
            
            
        }
    }
    
}

$Win32_PhysicalMemory | foreach {
        if ($Smbios)
        {
            $MemoryType=$MemTypeSmbios[[string]$DecMemtype] #
        }
        elseif($MemoryType -eq $null)
        {
            $MemoryType=$MemTypeWmi[[string]$_.memorytype]
        }
    
    $Property=@{
    Capacity=$_.capacity
    MemoryType=$MemoryType
    Speed=$_.speed
    Manufacturer=$_.Manufacturer
    PartNumber=$_.PartNumber
    }
    $MemModule=New-Object Psobject -Property $Property
    $MemModule.psobject.typenames.insert(0,"ModuleSystemInfo.SystemInfo.Memory.Modules")
    $MemModules+=$MemModule
}

$MemModules