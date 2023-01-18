#$Protocol="wsman"
#$Win32_DiskDrive=Get-WmiObject -Class Win32_DiskDrive
#$MSStorageDriver_FailurePredictData=Get-WmiObject -Class MSStorageDriver_FailurePredictData -Namespace Root\wmi
#$MSStorageDriver_FailurePredictStatus=Get-WmiObject -Class MSStorageDriver_FailurePredictStatus -Namespace Root\wmi
#$Win32_OperatingSystem=Get-WmiObject -Class Win32_OperatingSystem
#$computername="localhost"
function GetHddSmart
{
    param ($OsVersion)
	    function ConvertTo-Hex ( $DEC ) {
		    '{0:x2}' -f [int]$DEC
	    }
	    function ConvertTo-Dec ( $HEX ) {
		    [Convert]::ToInt32( $HEX, 16 )
	    }
function GetNvmeSmart{
<#
    source https://github.com/ken-yossy/nvmetool-win-powershell/blob/main/scripts/get-smart-log.ps1
#>
Param([parameter(Mandatory=$true)][Int]$PhyDrvNo)

$KernelService = Add-Type -Name 'Kernel32' -Namespace 'Win32' -PassThru -MemberDefinition @"
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr CreateFile(
        String lpFileName,
        UInt32 dwDesiredAccess,
        UInt32 dwShareMode,
        IntPtr lpSecurityAttributes,
        UInt32 dwCreationDisposition,
        UInt32 dwFlagsAndAttributes,
        IntPtr hTemplateFile);
    [DllImport("Kernel32.dll", SetLastError = true)]
    public static extern bool DeviceIoControl(
        IntPtr  hDevice,
        int     oControlCode,
        IntPtr  InBuffer,
        int     nInBufferSize,
        IntPtr  OutBuffer,
        int     nOutBufferSize,
        ref int pBytesReturned,
        IntPtr  Overlapped);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
"@

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct NVMeStorageQueryProperty {
    public UInt32 PropertyId;
    public UInt32 QueryType;
    public UInt32 ProtocolType;
    public UInt32 DataType;
    public UInt32 ProtocolDataRequestValue;
    public UInt32 ProtocolDataRequestSubValue;
    public UInt32 ProtocolDataOffset;
    public UInt32 ProtocolDataLength;
    public UInt32 FixedProtocolReturnData;
    public UInt32 ProtocolDataRequestSubValue2;
    public UInt32 ProtocolDataRequestSubValue3;
    public UInt32 ProtocolDataRequestSubValue4;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 512)]
    public Byte[] SMARTData;
//    Followings are the data structure of SMART Log page in NVMe rev1.4b
// 
//                                            // byte offset from the head of this structure
//    public Byte   CriticalWarning;          // byte 48
//    public UInt16 Temperature;              // byte 49
//    public Byte   AvailableSpare;           // byte 51
//    public Byte   AvailableSpareThreshold;  // byte 52
//    public Byte   PercentageUsed;           // byte 53
//    public Byte   EnduranceGroupSummary;    // byte 54
//    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 25)]
//    public Byte[] Reserved1;                // byte 55
//    public UInt64 DataUnitReadL;            // byte 80
//    public UInt64 DataUnitReadH;            // byte 88
//    public UInt64 DataUnitWrittenL;         // byte 96
//    public UInt64 DataUnitWrittenH;         // byte 104
//    public UInt64 HostReadCommandsL;        // byte 112
//    public UInt64 HostReadCommandsH;        // byte 120
//    public UInt64 HostWriteCommandsL;       // byte 128
//    public UInt64 HostWriteCommandsH;       // byte 136
//    public UInt64 ControllerBusyTimeL;      // byte 144
//    public UInt64 ControllerBusyTimeH;      // byte 152
//    public UInt64 PowerCycleL;              // byte 160
//    public UInt64 PowerCycleH;              // byte 168
//    public UInt64 PowerOnHoursL;            // byte 176
//    public UInt64 PowerOnHoursH;            // byte 184
//    public UInt64 UnsafeShutdownsL;         // byte 192
//    public UInt64 UnsafeShutdownsH;         // byte 200
//    public UInt64 MediaErrorsL;             // byte 208
//    public UInt64 MediaErrorsH;             // byte 216
//    public UInt64 ErrorLogInfoEntryNumL;    // byte 224
//    public UInt64 ErrorLogInfoEntryNumH;    // byte 232
//    public UInt32 WCTempTime;               // byte 240
//    public UInt32 CCTempTime;               // byte 244
//    public UInt16 TempSensor1;              // byte 248
//    public UInt16 TempSensor2;              // byte 250
//    public UInt16 TempSensor3;              // byte 252
//    public UInt16 TempSensor4;              // byte 254
//    public UInt16 TempSensor5;              // byte 256
//    public UInt16 TempSensor6;              // byte 258
//    public UInt16 TempSensor7;              // byte 260
//    public UInt16 TempSensor8;              // byte 262
//    public UInt32 TMT1TransitionCount;      // byte 264
//    public UInt32 TMT2TransitionCount;      // byte 268
//    public UInt32 TMT1TotalTime;            // byte 272
//    public UInt32 TMT2TotalTime;            // byte 276
//
//    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 280)]
//    public Byte[] Reserved2;                // byte 280
}
"@

$AccessMask = "3221225472"; # = 0xC00000000 = GENERIC_READ (0x80000000) | GENERIC_WRITE (0x40000000)
$AccessMode = 3; # FILE_SHARE_READ | FILE_SHARE_WRITE
$AccessEx   = 3; # OPEN_EXISTING
$AccessAttr = 0x40; # FILE_ATTRIBUTE_DEVICE

$DeviceHandle = $KernelService::CreateFile("\\.\PhysicalDrive$PhyDrvNo", [System.Convert]::ToUInt32($AccessMask), $AccessMode, [System.IntPtr]::Zero, $AccessEx, $AccessAttr, [System.IntPtr]::Zero);

$LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
if ($DeviceHandle -eq [System.IntPtr]::Zero) {
     Write-Error "`n[E] CreateFile failed: $LastError" -ErrorAction Stop
     
}

# offsetof(STORAGE_PROPERTY_QUERY, AdditionalParameters)
#  + sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA)
#  + sizeof(NVME_SMART_INFO_LOG) = 560
$OutBufferSize = 8 + 40 + 512; # = 560
$OutBuffer     = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($OutBufferSize);

$Property      = New-Object NVMeStorageQueryProperty;
$PropertySize  = [System.Runtime.InteropServices.Marshal]::SizeOf($Property);

if ( $PropertySize -ne $OutBufferSize ) {
    Write-Output "`n[E] Size of structure is $PropertySize bytes, expect 560 bytes, stop";
    Return;
}

$Property.PropertyId    = 50; # StorageDeviceProtocolSpecificProperty
$Property.QueryType     = 0;  # PropertyStandardQuery
$Property.ProtocolType  = 3;  # ProtocolTypeNvme
$Property.DataType      = 2;  # NVMeDataTypeLogPage

$Property.ProtocolDataRequestValue      = 2; # NVME_LOG_PAGE_HEALTH_INFO
$Property.ProtocolDataRequestSubValue   = 0; # LPOL
$Property.ProtocolDataRequestSubValue2  = 0; # LPOU
$Property.ProtocolDataRequestSubValue3  = 0; # Log Specific Identifier in CDW11
$Property.ProtocolDataRequestSubValue4  = 0; # Retain Asynchronous Event (RAE) and Log Specific Field (LSP) in CDW10

$Property.ProtocolDataOffset = 40;  # sizeof(STORAGE_PROTOCOL_SPECIFIC_DATA)
$Property.ProtocolDataLength = 512; # sizeof(NVME_SMART_INFO_LOG)

$ByteRet = 0;
$IoControlCode = 0x2d1400; # IOCTL_STORAGE_QUERY_PROPERTY

[System.Runtime.InteropServices.Marshal]::StructureToPtr($Property, $OutBuffer, [System.Boolean]::false);
$CallResult = $KernelService::DeviceIoControl($DeviceHandle, $IoControlCode, $OutBuffer, $OutBufferSize, $OutBuffer, $OutBufferSize, [ref]$ByteRet, [System.IntPtr]::Zero);

$LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error();
if ( $CallResult -eq 0 ) {
    Write-Error "`n[E] DeviceIoControl() failed: $LastError" -ErrorAction Stop
}

if ( $ByteRet -ne 560 ) {
    Write-Error "`n[E] Data size returned ($ByteRet bytes) is wrong; expect $OutBufferSize bytes" -ErrorAction Stop
    
}
function ConvertHexToDec{
    param(
        [string]$HexValue
    )
    return $([convert]::ToInt64($HexValue,16))
}
$DataUnitRead=$(ConvertHexToDec -HexValue $("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 88).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 80).ToString("X8"))))*512000
$DataUnitWritten=$(ConvertHexToDec -HexValue $("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 104).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 96).ToString("X8"))))*512000
$HostReadCommands=ConvertHexToDec -HexValue $("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 120).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 112).ToString("X8")))
$HostWriteCommands=ConvertHexToDec -HexValue $("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 136).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 128).ToString("X8")))
$Result=New-Object -TypeName psobject
$Result | Add-Member -MemberType NoteProperty -Name "CriticalWarning" -Value $("0x"+"$([System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 48).ToString("X2"))")
$Result | Add-Member -MemberType NoteProperty -Name "Temperature" -Value $([int]$([System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 49))-273) -Force -ErrorAction SilentlyContinue
$Result | Add-Member -MemberType NoteProperty -Name "AvailableSpare" -Value $([System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 51))
$Result | Add-Member -MemberType NoteProperty -Name "AvailableSpareThreshold" -Value $([System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 52))
$Result | Add-Member -MemberType NoteProperty -Name "PercentageUsed" -Value $([System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 53))
$Result | Add-Member -MemberType NoteProperty -Name "EnduranceGroupSummary" -Value $("0x"+[System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 54).ToString("X2"))
$Result | Add-Member -MemberType NoteProperty -Name "DataUnitRead" -Value $DataUnitRead
$Result | Add-Member -MemberType NoteProperty -Name "DataUnitWritten" -Value $DataUnitWritten
$Result | Add-Member -MemberType NoteProperty -Name "HostReadCommands" -Value $HostReadCommands
$Result | Add-Member -MemberType NoteProperty -Name "HostWriteCommands" -Value $HostWriteCommands
$Result | Add-Member -MemberType NoteProperty -Name "ControllerBusyTime" -Value $(New-TimeSpan -Minutes $([convert]::ToInt64($("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 152).ToString("X8"))+ [string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 144).ToString("X8"))),16)))
$Result | Add-Member -MemberType NoteProperty -Name "PowerCycles" -Value $([convert]::ToInt64($("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 168).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 160).ToString("X8"))),16))
$Result | Add-Member -MemberType NoteProperty -Name "PowerOnHours" -Value $(New-TimeSpan -Hours $([convert]::ToInt64($("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 184).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 176).ToString("X8"))),16)))
$Result | Add-Member -MemberType NoteProperty -Name "UnsafeShutdowns" -Value $(ConvertHexToDec -HexValue $("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 200).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 192).ToString("X8"))))
$Result | Add-Member -MemberType NoteProperty -Name "MediaDataIntegrityErrors" -Value $(ConvertHexToDec -HexValue $("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 216).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 208).ToString("X8"))))
$Result | Add-Member -MemberType NoteProperty -Name "NumberOfErrorInformationEntries" -Value $(ConvertHexToDec -HexValue $("0x"+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 232).ToString("X8"))+[string]$([System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 224).ToString("X8"))))
$Result
<#
#Write-Output( "Critical Warning: 0x{0}" -F [System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 48).ToString("X2") );
#Write-Output( "Composite Temperature: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 49) );
#Write-Output( "Available Spare: {0} (%)" -F [System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 51) );
#Write-Output( "Available Spare Threshold: {0} (%)" -F [System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 52) );
#Write-Output( "Percentage Used: {0} (%)" -F [System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 53) );
#Write-Output( "Endurance Group Summary: 0x{0}" -F [System.Runtime.InteropServices.Marshal]::ReadByte($OutBuffer, 54).ToString("X2") );
#Write-Output( "Data Unit Read: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 88).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 80).ToString("X8") );
#Write-Output( "Data Unit Written: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 104).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 96).ToString("X8") );
#Write-Output( "Host Read Commands: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 120).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 112).ToString("X8") );
#Write-Output( "Host Write Commands: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 136).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 128).ToString("X8") );
#Write-Output( "Controller Busy Time: 0x{0}{1} (minutes)" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 152).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 144).ToString("X8") );
#Write-Output( "Power Cycles: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 168).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 160).ToString("X8") );
#Write-Output( "Power On Hours: 0x{0}{1} (hours)" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 184).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 176).ToString("X8") );
#Write-Output( "Unsafe Shutdowns: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 200).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 192).ToString("X8") );
#Write-Output( "Media and Data Integrity Errors: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 216).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 208).ToString("X8") );
#Write-Output( "Number of Error Information Entries: 0x{0}{1}" -F [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 232).ToString("X8"), [System.Runtime.InteropServices.Marshal]::ReadInt64($OutBuffer, 224).ToString("X8") );
Write-Output( "Warning Composite Temperature Time: {0} (minutes)" -F [System.Runtime.InteropServices.Marshal]::ReadInt32($OutBuffer, 240) );
Write-Output( "Critical Composite Temperature Time: {0} (minutes)" -F [System.Runtime.InteropServices.Marshal]::ReadInt32($OutBuffer, 244) );
Write-Output( "Temperature Sensor 1: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 248) );
Write-Output( "Temperature Sensor 2: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 250) );
Write-Output( "Temperature Sensor 3: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 252) );
Write-Output( "Temperature Sensor 4: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 254) );
Write-Output( "Temperature Sensor 5: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 256) );
Write-Output( "Temperature Sensor 6: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 258) );
Write-Output( "Temperature Sensor 7: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 260) );
Write-Output( "Temperature Sensor 8: {0} (K)" -F [System.Runtime.InteropServices.Marshal]::ReadInt16($OutBuffer, 262) );
Write-Output( "Thermal Management Temperature 1 Transition Count: {0} (times)" -F [System.Runtime.InteropServices.Marshal]::ReadInt32($OutBuffer, 264) );
Write-Output( "Thermal Management Temperature 2 Transition Count: {0} (times)" -F [System.Runtime.InteropServices.Marshal]::ReadInt32($OutBuffer, 268) );
Write-Output( "Total Time For Thermal Management Temperature 1: {0} (seconds)" -F [System.Runtime.InteropServices.Marshal]::ReadInt32($OutBuffer, 272) );
Write-Output( "Total Time For Thermal Management Temperature 2: {0} (seconds)" -F [System.Runtime.InteropServices.Marshal]::ReadInt32($OutBuffer, 276) );
#>
[System.Runtime.InteropServices.Marshal]::FreeHGlobal($OutBuffer);
[void]$KernelService::CloseHandle($DeviceHandle);
}
function Get-AttributeDescription ( $Value ) {		
switch ($Value) {
			'01' { 'Raw Read Error Rate' }
			'02' { 'Throughput Performance' }
			'03' { 'Spin-Up Time' }
			'04' { 'Number of Spin-Up Times (Start/Stop Count)' }
			'05' { 'Reallocated Sector Count' }
			'07' { 'Seek Error Rate' }
			'08' { 'Seek Time Performance' }
			'09' { 'Power On Hours Count (Power-on Time)' }
			'0a' { 'Spin Retry Count' }
			'0b' { 'Calibration Retry Count (Recalibration Retries)' }
			'0c' { 'Power Cycle Count' }
			'aa' { 'Available Reserved Space' }
			'ab' { 'Program Fail Count' }
			'ac' { 'Erase Fail Count' }
			'ae' { 'Unexpected power loss count' }
			'b7' { 'SATA Downshift Error Count' }
			'b8' { 'End-to-End Error' }
            'bb' { 'Reported Uncorrected Sector Count (UNC Error)' }
			'bc' { 'Command Timeout' }
			'bd' { 'High Fly Writes' }
			'be' { 'Airflow Temperature' }
			'bf' { 'G-Sensor Shock Count (Mechanical Shock)' }
			'c0' { 'Power Off Retract Count (Emergency Retry Count)' }
			'c1' { 'Load/Unload Cycle Count' }
			'c2' { 'Temperature' }
			'c3' { 'Hardware ECC Recovered' }
			'c4' { 'Reallocated Event Count' }
			'c5' { 'Current Pending Sector Count' }
			'c6' { 'Offline Uncorrectable Sector Count' }
			'c7' { 'UltraDMA CRC Error Count' }
			'c8' { 'Write Error Rate (MultiZone Error Rate)' }
			'c9' { 'Soft Read Error Rate' }
			'cb' { 'Run Out Cancel' }
			'cà' { 'Data Address Mark Error' }
			'dc' { 'Disk Shift' }
			'e1' { 'Load/Unload Cycle Count' }
			'e2' { 'Load ''In''-time' }
			'e3' { 'Torque Amplification Count' }
			'e4' { 'Power-Off Retract Cycle' }
			"e7" {'SSDLife'}
            'e8' { 'Endurance Remaining' }
			'e9' { 'Media Wearout Indicator' }
			'f0' { 'Head Flying Hours' }
			'f1' { 'Total LBAs Written' }
			'f2' { 'Total LBAs Read' }
			'f9' { 'NAND Writes (1GiB)' }
			'fe' { 'Free Fall Protection' }
			default { $Value }
		}
	}

    $PnpDev=@{}
    $hdddev=$Win32_DiskDrive | Select-Object Model,Size,MediaType,InterfaceType,FirmwareRevision,SerialNumber,PNPDeviceID,Index
    $hdddev | foreach {
        $PnpDev.Add($($_.pnpdeviceid -replace "\\","\\"),$_)
    }
    $AllHddSmart=@()
    if ([version]$OsVersion -ge [version]"6.2")
    {
        #https://msdn.microsoft.com/en-us/library/windows/desktop/hh830532(v=vs.85)#methods
        $BusTypeHashTable=@{
            "0"="Unknown"
            "1"="SCSI"
            "2"="ATAPI"
            "3"="ATA"
            "4"="IEEE 1394"
            "5"="SSA"
            "6"="FibreChannel"
            "7"="USB"
            "8"="RAID"
            "9"="iSCSI"
            "10"="SAS"
            "11"="SATA"
            "12"="SD"
            "13"="MMC"
            "15"="FileBackedVirtual"
            "16"="StorageSpaces"
            "17"="NVMe"
        }
        $MediaTypeHashTable=@{
            "0"="Unknown"
            "3"="HDD"
            "4"="SSD"
            "5"="SCM"
        }

        Write-Verbose "$ComputerName Windows 8 or later detected"
        if ($credential -eq $null)
        {
            $MSFT_PhysicalDisk=Get-WmiObject -Class MSFT_PhysicalDisk -Namespace root\Microsoft\Windows\Storage -ComputerName $computername -ErrorAction SilentlyContinue
        }
        else
        {
           $MSFT_PhysicalDisk= Get-WmiObject -Class MSFT_PhysicalDisk -Namespace root\Microsoft\Windows\Storage -ComputerName $computername -Credential $credential -ErrorAction SilentlyContinue
        }

    }
    
    $PnpDev.Keys | foreach {
        $PnpDevid=$_
        $TmpFailData=$MSStorageDriver_FailurePredictData | Where-Object  {$_.InstanceName -Match $PnpDevid}
        $TmpFailStat=$MSStorageDriver_FailurePredictStatus | Where-Object  {$_.InstanceName -Match $PnpDevid}
        if ($TmpFailStat)
        {
            $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name  PredictFailure -Value $TmpFailStat.PredictFailure
        }
        else
        {
            $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name  PredictFailure -Value 'Unknown'
        }
        if ($TmpFailData)
        {
            $Disk=$TmpFailData
            $i = 0
            #$Report = @()
            $pByte = $null
		            foreach ( $Byte in $Disk.VendorSpecific ) {
			            $i++
			            if (( $i - 3 ) % 12 -eq 0 ) 
                        {
				            if ( $Byte -eq 0) { break }
				            $Attribute = '{0:x2}' -f [int]$Byte
			            } 
                        else 
                        {
				            $post = ConvertTo-Hex $pByte
				            $pref = ConvertTo-Hex $Byte
				            $Value = ConvertTo-Dec "$pref$post"
				            if (( $i - 3 ) % 12 -eq 6 ) 
                            {
					            if ( $Attribute -eq '09' ) { [int]$Value = $Value / 24 }
				                $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name $(Get-AttributeDescription $Attribute) -Value $Value -Force
                            }
			            }
			            $pByte = $Byte
                    }
        
        }
        elseif($MSFT_PhysicalDisk -eq $null)
        {
            $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Unknown' 
        }
        $HddSmart=$PnpDev[$PnpDevid]
        if ($MSFT_PhysicalDisk -ne $null){
            $MsftDisk=$MSFT_PhysicalDisk | Where-Object  {$_.DeviceId -eq $HddSmart.Index}
            $InterfaceType=$BusTypeHashTable["$($MsftDisk.bustype)"]
            if($HddSmart.PNPDeviceID -match "nvme"){
                    $InterfaceType="NVMe"
            }
            $MediaType=$MediaTypeHashTable["$($MsftDisk.mediatype)"]
            
            if ($InterfaceType -ne $null){
                $HddSmart.InterfaceType=$InterfaceType
                if($InterfaceType -eq "NVMe"){
                    if($Protocol -eq "WSMAN"){
                        Write-Verbose "$ComputerName GetNvmeSmart -PhyDrvNo  $($HddSmart.Index)"
                        try{
                            $NVMeSmartResult=GetNvmeSmart -PhyDrvNo  $HddSmart.Index -ErrorAction Stop
                            $NVMeSmartResult | Get-Member | Where-Object {
                                $_.membertype -eq "NoteProperty"
                            } | foreach {
                                    $PropertyName=$_.Name
                                    if(-not [string]::IsNullOrEmpty($PropertyName)){
                                        $PropertyValue=$NVMeSmartResult.$PropertyName
                                        $HddSmart | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $PropertyValue
                                    
                                    }             
                            }
                            if ([int]$HddSmart.PercentageUsed -gt 0){
                                $HddSmart | Add-Member -MemberType NoteProperty -Name SSDLife -Value $(100-$HddSmart.PercentageUsed)
                            }elseif([int]$HddSmart.PercentageUsed -eq 0){
                                $HddSmart | Add-Member -MemberType NoteProperty -Name SSDLife -Value 100
                            }
                        
                        }catch{
                            
                            Write-Verbose "$ComputerName $_"
                        }

                    }else{
                        Write-Verbose "$ComputerName Use wsman protocol to get smart options for nwme"
                    }
                    if($NVMeSmartResult -eq $null){
                        $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Unknown' 
                    }
                }elseif(-not $TmpFailData){
                    $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Unknown'
                }
                
            }
           
                $HddSmart | Add-Member -MemberType NoteProperty -Name Type -Value $MediaType
        }else{
            $HddSmart  | Add-Member -MemberType NoteProperty -Name Type -Value "Unknown"
        }
        
        if($HddSmart.InterfaceType -eq "NVMe"){
            $WarningTempThreshold=@(61,65)
        }else{
            $WarningTempThreshold=@(48,54)
        }
        
        
        $WarningThreshold=@{
            "Temperature"=$WarningTempThreshold
            "Reallocated Sector Count"=1,10
            "Reallocated Event Count"=1,10
            "Offline Uncorrectable Sector Count"=1,10
            "Current Pending Sector Count"=1,10
        }
        if($HddSmart.InterfaceType -eq "NVMe"){
            $CriticalTempThreshold=69
        }else{
            $CriticalTempThreshold=55    
        }
        
        $CriticalThreshold=@{
            "Temperature"=$CriticalTempThreshold
            "Reallocated Sector Count"=11
            "Reallocated Event Count"=11
            "Offline Uncorrectable Sector Count"=11
            "Current Pending Sector Count"=11
        }
            
            $HddWarning=$False
            $HddCritical=$False
            $HddSmart | Get-Member | foreach {
                $Property=$_.name
                if (!$HddCritical)
                {
                    if ($WarningThreshold[$Property])
                    {
                        $MinWarningThreshold=$WarningThreshold[$Property][0]
                        $MaxWarningThreshold=$WarningThreshold[$Property][1]
                            if ($HddSmart.$Property -le $MaxWarningThreshold -and $HddSmart.$Property -ge $MinWarningThreshold)
                            {
                                $HddWarning=$true
                                $Cause=$($Property -replace " ")+" "+[string]$($HddSmart.$Property)
                                if ($HddSmart.$Property -ge $WarningEventCount)
                                {
                                    $RootCause=$Cause
                                    $WarningEventCount=$HddSmart.$Property
                                }
                                Write-Verbose "Smart Warning $cause"
                            
                            }
                    }
                }
                if ($CriticalThreshold[$Property])
                {
                    $MinCriticalThreshold=$CriticalThreshold[$Property]
                        if($HddSmart.$Property -ge $MinCriticalThreshold)
                        {
                            $HddCritical=$true
                            $Cause=$($Property -replace " ")+" "+[string]$($HddSmart.$Property)
                            if ($HddSmart.$Property -ge  $CriticalEventCount)
                            {
                                $RootCause=$Cause    
                                $CriticalEventCount=$HddSmart.$Property
                            }
                            Write-Verbose "Smart Critical $cause" 
                        
                        } 
                }
              
            
            #End Foreach
            }
        if ($HddSmart.smartstatus -ne "Unknown")
        {
            if ($HddWarning)
            {
                $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value "Warning:$RootCause" 
            }
            elseif($HddCritical -or $HddSmart.PredictFailure -eq $true)
            {
                if($HddSmart.PredictFailure -eq $true){
                    $RootCause="PredictFailure"
                }
                $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value "Critical:$RootCause"   
            }
            else
            {
                if ($HddSmart.SSDLife -ne $null){
                    $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value "Ok:$($HddSmart.SSDLife)%" 
                }elseif([int]$HddSmart.'Endurance Remaining' -gt 0){
                    $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value "Ok:$($HddSmart.'Endurance Remaining')%" 
                }else{
                    $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value "Ok"  
                }
                 
            }
        }
    $AllHddSmart+=$HddSmart
    #End Foreach
    }

    $AllHddSmart
    


}
#GetHddSmart -OsVersion $($Win32_OperatingSystem.version)