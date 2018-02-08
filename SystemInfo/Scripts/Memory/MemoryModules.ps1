$MemoryTypeArray=@{
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
#$MemModules=$Win32_PhysicalMemory | Select-Object Capacity,MemoryType,Speed,Manufacturer,PartNumber
$MemModules=@()
$Win32_PhysicalMemory | foreach {
    $Property=@{
    Capacity=$_.capacity
    MemoryType=$MemoryTypeArray[[string]$_.memorytype]
    Speed=$_.speed
    Manufacturer=$_.Manufacturer
    PartNumber=$_.PartNumber
    }
    $MemModule=New-Object Psobject -Property $Property
    $MemModule.psobject.typenames.insert(0,"ModuleSystemInfo.SystemInfo.Memory.Modules")
    $MemModules+=$MemModule
}

$MemModules