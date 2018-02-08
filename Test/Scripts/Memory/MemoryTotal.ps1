$Win32_PhysicalMemory | Select-Object Capacity | foreach {
$MemTotalCount+=$_.capacity
}
$MemTotalCount