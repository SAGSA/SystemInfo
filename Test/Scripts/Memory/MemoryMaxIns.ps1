$MemMaxinsCount=0													
$Win32_PhysicalMemoryArray | foreach {$MemMaxinsCount+=$_.MaxCapacity*1kb}
$MemMaxinsCount