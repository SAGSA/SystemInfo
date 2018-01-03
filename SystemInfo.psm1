<#
.SYNOPSIS
    Very fast displays system information on a local or remote computer.

.DESCRIPTION
    The function uses WMI to collect information related to the characteristics of the computer
    The function uses multithreading. Multithreading is implemented through powershell runspace and WMI Job
    The function allows you to quickly get the system information of a large number of computers on the network
    After executing, two variables are created: 
    $Result-contains successful queries, 
    $ErrorResult-contains computers that have errors.

.PARAMETER MaxJob
    Specifies the maximum number of WMI and Runspace operations that can be executed simultaneously.
    By default, the value of this parameter is 254.

.PARAMETER JobTimeout
    Specifies the amount of time that the function waits for a response from the wmi job or runspace job.
    By default, the value of this parameter is 120 seconds.

.PARAMETER AppendToResult
    Adds the output to the $Result global variable. Without this parameter, $Result global variable replaces.

.PARAMETER Credential
    Specifies a user account that has permission to perform this action. The default is the current user. Type a user n
    ame, such as "User01", "Domain01\User01", or User@domain01.com. Or, enter a PSCredential object, such as an object t
    hat is returned by the Get-Credential cmdlet. When you type a user name, you are prompted for a password.

.PARAMETER ShowStatistics
    Show statistics information

.EXAMPLE
    Get-SystemInfo

    ComputerName     : Localhost
    OsCaption        : Майкрософт Windows 10 Pro
    OsArchitecture   : 64-разрядная
    OsUpTime         : 10:1:17:41
    OsLoggedInUser   : Domain\Username
    CPUName          : Intel(R) Core(TM) i3-2105 CPU @ 3.10GHz
    MotherboardModel : H61M-S1
    DeviceModel      : To be filled by O.E.M.
    MemoryTotal      : 4,0Gb
    MemoryModules    :
                       Capacity MemoryType Speed Manufacturer PartNumber
                       -------- ---------- ----- ------------ ----------
                       2Gb      DDR3       1333  Kingston     99U5595-005.A00LF
                       2Gb      DDR3       1333  Kingston     99U5595-005.A00LF



    HddDevices       :
                       Size  InterfaceType Model                           PredictFailure
                       ----  ------------- -----                           --------------
                       112Gb IDE           KINGSTON SHFS37A120G ATA Device False
                       149Gb IDE           ST3160813AS ATA Device          False



    VideoModel       : Intel(R) HD Graphics 3000
    MonitorName      : E2042
    CdRom            : TSSTcorp CDDVDW SH-222BB

    This command get the system information on the local computer.

.EXAMPLE
    Get-SystemInfo -Computername comp1,comp2,comp3
    This command receives system information from computers comp1, comp2, comp3. By default, the current account must be a member of the Administrators group on the
    remote computer.

.EXAMPLE
    1..254 | foreach {"192.168.1.$_"} | Get-SystemInfo -Properties OsCaption,OSArchitecture,OsInstallDate -Credential Domain01\administrator01 | Out-GridView
    Get OsCaption, OSArchitecture, OsInstallDate from the computers that are in the 192.168.1.0/24 network and sends them to a grid view window. This command uses 
    the Credential parameter. The value of the Credential parameter is a user account name. The user is prompted for a password.

.EXAMPLE
    Get-ADComputer -Filter * | Get-SystemInfo -Cpu -Motherboard -Memory -Properties OsVersion,OsProductKey -MaxJob 100 -JobTimeOut 30
    Get CPU, Motherboard, Memory and OsVersion, OsProductKey information from all domain computers. The module activedirectory must be installed and loaded. 
    This command uses MaxJob and JobTimeOut parameter.

.EXAMPLE 
    Get-SystemInfo -RegistryKey "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -RegistryValue SMB1 -RegistryValueType GetDWORDValue
    This command gets the SMB1 registry value
    If errors occur, such as timeout expired  or other errors.
    After some time, you can repeat the command for computers that have had errors.To do this, you need to use the variable $ErrorResult and -AppendToResult parameter to add the result to a variable $Result. 

    PS C:\>$ErrorResult | Get-SystemInfo -RegistryKey "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -RegistryValue SMB1 -RegistryValueType GetDWORDValue -AppendToResult

.EXAMPLE
    Get-Content -Path C:\Computers.txt | Get-SystemInfo -Properties MemoryTotal,OsLoggedInUser -WarningAction SilentlyContinue | Where-Object {$_.memorytotal -lt 1.5gb}
    This command gets computers that have a RAM size less than 1.5 gb. List of computers is taken from the file C:\Computers.txt. This command use parameter -WarningAction SilentlyContinue to ignore warning.
    
.EXAMPLE
    Get-Content -Path C:\Computers.txt  | Get-SystemInfo -Properties OsLoggedInUser,HddSmart | Where-Object {$_.hddsmart.smartstatus -eq "Critical" -or $_.hddsmart.smartstatus -eq "Warning"}
    This command gets computers that have hard disk problems
.EXAMPLE
    $Computers=Get-Content -Path C:\Computers.txt
    Get-SystemInfo -Computername $Computers | ConvertTo-Html -Head "SystemInformation" | Out-File -FilePath C:\report.html
    This command create html report
.NOTES
    Author: SAGSA
    https://github.com/SAGSA/SystemInfo
    Requires: Powershell 2.0

#>

function Get-SystemInfo
{
[CmdletBinding()]
    param(
            [parameter(ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,Position=0)]
            [Alias('CN','Computername','DnsHostname')]
            [string[]]$Name="127.0.0.1",          
            [switch]$OsInfo,
            [switch]$Cpu,
            [switch]$Motherboard,
            [switch]$Memory,
            [switch]$HDD,
            [switch]$Video,
            [switch]$Monitor,
            [switch]$NetworkAdapter,
            [switch]$PrinterInfo,
            [switch]$UsbDevices,
            [switch]$SoftwareList,
            [string]$RegistryKey,
            [string]$RegistryValue,
            [ValidateSet("GetStringValue","GetBinaryValue","GetDWORDValue")]
            [string]$RegistryValueType,
            $Credential,
            [Alias("ThrottleLimit")]
            [ValidateRange(1,1000)]
            [int]$MaxJob=254,
            [Alias("Timeout")]
            [ValidateRange(1,6000)]
            [int]$JobTimeOut=120,
            [switch]$AppendToResult,
            [switch]$ShowStatistics,
            [ValidateSet("*","OsVersion","OSArchitecture","OsCaption","OsInstallDate","OsUpTime","OsLoggedInUser","OsProductKey","MemoryTotal","MemoryFree","MemoryModules","MemoryModInsCount",
            "MemoryMaxIns","MemorySlots","ECCType","MemoryAvailable","Motherboard","MotherboardModel","DeviceModel","Cdrom","CdromMediatype","HddDevices","HddDevCount","HDDSmart",
            "HddSmartStatus","VideoModel","VideoRam","VideoProcessor","CPUName","CPUSocket","MaxClockSpeed","CPUCores","CPULogicalCore","MonitorManuf",
            "MonitorPCode","MonitorSN","MonitorName","MonitorYear","NetPhysAdapCount","NetworkAdapters","Printers","IsPrintServer","UsbConPrOnline","UsbDevices","CPULoad","SoftwareList","RegistryValue","OsAdministrators","OsActivationStatus")] 
            [array]$Properties
            
            )
begin
{
#Config
#################################################################################################################################
#Default Information (information output when executed Get-SystemInfo without parameters)
$DefaultInfoConfig="OsCaption","OsArchitecture","OsUpTime","OsLoggedInUser","CPUName","MotherboardModel","DeviceModel","MemoryTotal","MemoryModules","HddDevices","VideoModel","MonitorName","CdRom"

#FunctionConfig
$FunctionConfig=@{
OsVersion=          '-Class Win32_OperatingSystem -Property Version'
OsCaption=          '-Class Win32_OperatingSystem -Property Caption'
OSArchitecture=     '-Class Win32_OperatingSystem -Property OSArchitecture'
OsInstallDate=      '-Class Win32_OperatingSystem -ScriptBlock $SBOsInstalldate'
OsUpTime=           '-Class Win32_OperatingSystem -ScriptBlock $SbOsUpTime'
MemoryTotal=        '-Class Win32_PhysicalMemory -ScriptBlock $SbMemoryTotal'
MemoryAvailable=    '-Class Win32_OperatingSystem -ScriptBlock $SbMemoryAvailable'
MemoryFree=         '-Class Win32_OperatingSystem -ScriptBlock $SbMemoryFree'                           
MemoryModules=      '-Class Win32_PhysicalMemory -ScriptBlock $SbMemoryModules'
MemoryModInsCount=  '-Class Win32_PhysicalMemory -ScriptBlock $SbMemoryModInsCount'
MemoryMaxIns=       '-Class Win32_PhysicalMemoryArray -ScriptBlock $SbMemoryMaxIns'
MemorySlots=        '-Class Win32_PhysicalMemoryArray -ScriptBlock $SbMemorySlots'
ECCType=            '-Class Win32_PhysicalMemoryArray -ScriptBlock $SbECCType'
Motherboard=        '-Class Win32_BaseBoard -Property Manufacturer'
MotherboardModel=   '-Class Win32_BaseBoard -Property Product'
DeviceModel=        '-Class Win32_Computersystem -Property model'
Cdrom=              '-Class Win32_CDROmDrive -Property Caption'
CdromMediatype=     '-Class Win32_CDROMDrive -Property MediaType'
HddDevices=         '-Class Win32_DiskDrive,MSStorageDriver_FailurePredictStatus,MSStorageDriver_FailurePredictData -ScriptBlock $SbHddDevices'
HddDevCount=        '-Class Win32_DiskDrive -ScriptBlock $SbHddDevCount'
HddPredictFailure=  '-Class MSStorageDriver_FailurePredictStatus -Property PredictFailure'
VideoModel=         '-Class Win32_VideoController     -ScriptBlock $SbVideoModel'
VideoRam=           '-Class Win32_VideoController     -ScriptBlock $SbVideoRamMb'
VideoProcessor=     '-Class Win32_VideoController     -ScriptBlock $SbVideoProcessor'
CPUName=            '-Class Win32_Processor -Property Name'
CPUSocket=          '-Class Win32_Processor -Property SocketDesignation'
MaxClockSpeed=      '-Class Win32_Processor -Property MaxClockSpeed'
CPUCores=           '-Class Win32_Processor -Property NumberOfCores'
CPULogicalCore=     '-Class Win32_Processor -Property NumberOfLogicalProcessors'
CPULoad=            '-Class Win32_Processor -Property LoadPercentage'
MonitorManuf=       '-Class wmiMonitorID -ScriptBlock $SBMonitorManuf'
MonitorPCode=       '-Class wmiMonitorID -ScriptBlock $SBMonPCode'
MonitorSN=          '-Class wmiMonitorID -ScriptBlock $SbMonSn'
MonitorName=        '-Class wmiMonitorID -ScriptBlock $SbMonName'
MonitorYear=        '-Class wmiMonitorID -Property YearOfManufacture'
NetworkAdapters=    '-Class Win32_NetworkAdapterConfiguration -ScriptBlock $SbNetworkAdapters'
NetPhysAdapCount=   '-Class Win32_NetworkAdapter -ScriptBlock $SbNetPhysAdapCount'
Printers=           '-Class Win32_Printer -ScriptBlock $SbPrinters'
UsbConPrCount=      '-Class Win32_Printer -ScriptBlock $SbUsbConPrCount'
IsPrintServer=      '-Class Win32_Printer -ScriptBlock $SbIsPrintServer'
UsbConPrOnline=     '-Class Win32_Printer -ScriptBlock $SbUsbConPrOnline'
UsbDevices=         '-Class Win32_USBControllerDevice -ScriptBlock $SbUsbDevices'
RegistryValue=      '-Class StdRegProv -ScriptBlock $SbGetRegistryValue -UseRunspace -RunspaceImportVariable $RegistryKey,$RegistryValue,$RegistryValueType'
SoftwareList=       '-Class StdRegProv -ScriptBlock $SbSoftwareList -UseRunspace'
OsProductKey=       '-Class StdRegProv -ScriptBlock $SBOsProductKey -UseRunspace'
OsLoggedInUser=     '-Class Win32_ComputerSystem -Property UserName'
OsAdministrators=   '-Class Win32_OperatingSystem -Scriptblock $SbOsAdministrators -UseRunspace'
OsActivationStatus= '-Query Select * From SoftwareLicensingProduct Where ApplicationID = "55c92734-d682-4d71-983e-d6ec3f16059f" And Licensestatus > 0 -ScriptBlock $SbOsActivationStatus'
HDDSmart=           '-Class MSStorageDriver_FailurePredictStatus,MSStorageDriver_FailurePredictData,Win32_DiskDrive -ScriptBlock $SbHddSmart'
HddSmartStatus=     '-Class MSStorageDriver_FailurePredictStatus,MSStorageDriver_FailurePredictData,Win32_DiskDrive -ScriptBlock $SbHddSmartStatus'
}

$ManualNamespace=@{
wmiMonitorID='-Namespace Root\wmi'
MSStorageDriver_FailurePredictStatus='-Namespace Root\wmi'
MSStorageDriver_FailurePredictData='-Namespace Root\wmi'
StdRegProv='-Namespace ROOT\default -Query SELECT * FROM meta_class WHERE __class="StdRegProv"'
}

#End FunctionConfig
#################################################################################################################################
#Config Switch Param
$SwitchConfig=@{
OSInfo="OsVersion","OSArchitecture","OsCaption","OsInstallDate","OsUpTime","OsProductKey","OsLoggedInUser","OsActivationStatus",'OsAdministrators'
Cpu="CPUName","CPUSocket","MaxClockSpeed","CPUCores","CPULogicalCore","CPULoad"
Hdd="HddDevices","HddDevCount"
Motherboard="Motherboard","MotherboardModel","DeviceModel"
Memory="MemoryTotal","MemoryFree","MemoryModules","MemoryMaxIns","MemorySlots","MemoryAvailable","MemoryModInsCount","ECCType"
Video="VideoModel","VideoRam","VideoProcessor"
Monitor="MonitorManuf","MonitorName","MonitorPCode","MonitorSN","MonitorYear"
NetworkAdapter="NetworkAdapters","NetPhysAdapCount"
PrinterInfo="Printers","UsbConPrCount","IsPrintServer","UsbConPrOnline"
UsbDevices="UsbDevices"
SoftwareList="SoftwareList"
}

#Exclude switch Param
$ExcludeParam="Verbose","AppendToResult","Debug","ShowStatistics"
#End Config Switch Param

#################################################################################################################################
$LocalComputer=$env:COMPUTERNAME,"Localhost","127.0.0.1"
$AdminRequired="HDDSmart","HddDevices","HddSmartStatus"
$RequiredExecutionPolicy="Unrestricted","RemoteSigned"
#End Config

#ScriptBlock
#################################################################################################################################
[scriptblock]$SbHddSmartStatus=
{
GetHddSmart | foreach {$_.smartstatus}
}
[scriptblock]$SbHddSmart=
{
GetHddSmart
}

[scriptblock]$SbOsActivationStatus={

$ActStat=@{
"1"  = "Licensed"
"2"  = "Out-Of-Box Grace Period"
"3"  = "Out-Of-Tolerance Grace Period"
"4"  = "Non-Genuine Grace Period"
"5"  = "Notification"
"6"  = "Extended Grace"
}

if ($Query_SoftwareLicensingProduct_OsActivationStatus)
{
$LicStat=($Query_SoftwareLicensingProduct_OsActivationStatus.Licensestatus).tostring()
$Stat=$ActStat[$LicStat]
    if (!$Stat)
    {
        $Stat="Unknown value $($Query_SoftwareLicensingProduct_OsActivationStatus.Licensestatus)"
    }
    if ($Query_SoftwareLicensingProduct_OsActivationStatus.Description -match ".+,\s?(.+)")
    {
        $Descr=$Matches[1]
    }
    else
    {
        $Query_SoftwareLicensingProduct_OsActivationStatus.Description
    }
    
$KmsPort=$Query_SoftwareLicensingProduct_OsActivationStatus.KeyManagementServicePort
$KmsServer=$Query_SoftwareLicensingProduct_OsActivationStatus.KeyManagementServiceMachine
    if ($KmsServer -and $KmsPort)
    {
        $FullKms=$KmsServer+":"+$KmsPort
    }
    else
    {
        $FullKms=$null
    }
    
}
else
{
    $Stat="Unlicensed or Unknown"
}
$Prop=@{
    "Status"=$Stat
    "Description"=$Descr
}
if ($FullKms)
{
    $Prop.Add("KMSServer",$FullKms)
}
$DispObj=New-Object psobject -Property $Prop
$DispObj
}

[scriptblock]$SbOsAdministrators={
try{
$LangAdminGroups=@{
#Key https://msdn.microsoft.com/ru-ru/library/ms912047(v=winembedded.10).aspx Value Administrators Group
"1049"="Администраторы"
"1033"="Administrators"
}
$ComputerName=$Win32_OperatingSystem.__SERVER
$GroupName=$LangAdminGroups["$($Win32_OperatingSystem.OSLanguage)"]
if ($GroupName -eq $Null)
{
    $GroupName="Administrators"
}
$wmitmp = Get-WmiObject -ComputerName $ComputerName -Query "SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`"" -ErrorAction Stop
if ($wmitmp -ne $null)  
{  
$DispObjArray=@()
$wmitmp | foreach{   
    if ($_.PartComponent -match '(.+:)?(.+)\..+?="(.+?)",Name="(.+?)"')
    {
    $Type=$Matches[2]
    $Domain=$matches[3]
    $Name=$Matches[4]
        if ($domain -eq $computername)
        {
            $IsLocalAccount=$True
        }
        else
        {
            $IsLocalAccount=$false
        }
                    
    $DispObj=New-Object psobject 
    $DispObj | Add-Member -MemberType NoteProperty -Name FullName -Value "$Domain\$Name"
    #$DispObj | Add-Member -MemberType NoteProperty -Name Domain -Value $Domain
    #$DispObj | Add-Member -MemberType NoteProperty -Name Name -Value $Name
    $DispObj | Add-Member -MemberType NoteProperty -Name Type -Value $Type
    $DispObj | Add-Member -MemberType NoteProperty -Name IsLocal -Value $IsLocalAccount
    $DispObjArray+=$DispObj 
    }
                
}  
$DispObjArray | Sort-Object -Property IsLocal,Type
} 
else
{
    Write-Error -Message "Query SELECT * FROM Win32_GroupUser WHERE GroupComponent=`"Win32_Group.Domain='$ComputerName',Name='$GroupName'`" return null value. Check LangAdminGroups hashtable" -ErrorAction Stop
} 
}catch{
    $_
}
}

[scriptblock]$SBOsInstalldate=
{
[Management.ManagementDateTimeConverter]::ToDateTime($Win32_OperatingSystem.installdate)
}

[scriptblock]$SbOsUpTime=
{
$Uptime=$Win32_OperatingSystem.ConvertToDateTime($Win32_OperatingSystem.LocalDateTime) –$Win32_OperatingSystem.ConvertToDateTime($Win32_OperatingSystem.LastBootUpTime)
"$($Uptime.days)"+":"+"$($Uptime.hours)"+":"+"$($Uptime.minutes)"+":"+"$($Uptime.seconds)"
}

[scriptblock]$SbMemoryTotal=
{
$Win32_PhysicalMemory | Select-Object Capacity | foreach {
$MemTotalCount+=$_.capacity
}
$MemTotalCount
}

[scriptblock]$SbMemoryAvailable=
{
$Win32_OperatingSystem.TotalVisibleMemorySize * 1kb
}

[scriptblock]$SbMemoryFree=
{
$Win32_OperatingSystem.FreePhysicalMemory*1kb
}

[scriptblock]$SbMemoryModInsCount=
{
$count=0
$Win32_PhysicalMemory | foreach {$count++}
$count
}

[scriptblock]$SbMemoryModules=
{
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
}

[scriptblock]$SbMemorySlots=
{
$Win32_PhysicalMemoryArray | foreach {$_.memorydevices}
}

[scriptblock]$SbECCType=
{
$MemoryEccArray=@{'0'='Reserved';
'1'='Other';
'2'='Unknown';
'3'='None';
'4'='Parity';
'5'='Single-bit ECC';
'6'='Multi-bit ECC';
'7'='CRC'
}
$Win32_PhysicalMemoryArray| foreach{$MemoryEccArray[[string]$_.MemoryErrorCorrection]}
}

[scriptblock]$SbHddDevices=
{

$DispInfo=GetHddSmart | foreach {
    $Property=@{
    Size=$_.Size
    InterfaceType=$_.InterfaceType
    Model=$_.Model
    SmartStatus=$_.SmartStatus
    }
    $TmpObj=New-Object psobject -Property $Property
    $TmpObj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.Devices")
    $TmpObj
}

$DispInfo
}

[scriptblock]$SbHddDevCount=
{
$count=0
$Win32_DiskDrive | foreach {$count++}
$count
}

[scriptblock]$SbVideoModel=
{
$Win32_VideoController | foreach {
    if ($_.name -notmatch "Radmin.+" -and $_.name -notmatch "DameWare.+")
	{
	    $_.name															
	} 
}

}

[scriptblock]$SbVideoRamMb=
{
$Win32_VideoController | foreach {
    if ($_.name -notmatch "Radmin.+" -and $_.name -notmatch "DameWare.+")
    {															
	    $_.AdapterRAM															
    } 
}

}

[scriptblock]$SbVideoProcessor=
{
$Win32_VideoController | foreach {
    if ($_.name -notmatch "Radmin.+" -and $_.name -notmatch "DameWare.+")
	{																
	    $_.VideoProcessor															
	} 
}

}

[scriptblock]$SBMonitorManuf=
{
$ManufacturerHashTable = @{ 
    "AAC" =	"AcerView";
    "ACR" = "Acer";
    "AOC" = "AOC";
    "AIC" = "AG Neovo";
    "APP" = "Apple Computer";
    "AST" = "AST Research";
    "AUO" = "Asus";
    "BNQ" = "BenQ";
    "CMO" = "Acer";
    "CPL" = "Compal";
    "CPQ" = "Compaq";
    "CPT" = "Chunghwa Pciture Tubes, Ltd.";
    "CTX" = "CTX";
    "DEC" = "DEC";
    "DEL" = "Dell";
    "DPC" = "Delta";
    "DWE" = "Daewoo";
    "EIZ" = "EIZO";
    "ELS" = "ELSA";
    "ENC" = "EIZO";
    "EPI" = "Envision";
    "FCM" = "Funai";
    "FUJ" = "Fujitsu";
    "FUS" = "Fujitsu-Siemens";
    "GSM" = "LG Electronics";
    "GWY" = "Gateway 2000";
    "HEI" = "Hyundai";
    "HIT" = "Hyundai";
    "HSL" = "Hansol";
    "HTC" = "Hitachi/Nissei";
    "HWP" = "HP";
    "IBM" = "IBM";
    "ICL" = "Fujitsu ICL";
    "IVM" = "Iiyama";
    "KDS" = "Korea Data Systems";
    "LEN" = "Lenovo";
    "LGD" = "Asus";
    "LPL" = "Fujitsu";
    "MAX" = "Belinea"; 
    "MEI" = "Panasonic";
    "MEL" = "Mitsubishi Electronics";
    "MS_" = "Panasonic";
    "NAN" = "Nanao";
    "NEC" = "NEC";
    "NOK" = "Nokia Data";
    "NVD" = "Fujitsu";
    "OPT" = "Optoma";
    "PHL" = "Philips";
    "REL" = "Relisys";
    "SAN" = "Samsung";
    "SAM" = "Samsung";
    "SBI" = "Smarttech";
    "SGI" = "SGI";
    "SNY" = "Sony";
    "SRC" = "Shamrock";
    "SUN" = "Sun Microsystems";
    "SEC" = "Hewlett-Packard";
    "TAT" = "Tatung";
    "TOS" = "Toshiba";
    "TSB" = "Toshiba";
    "VSC" = "ViewSonic";
    "ZCM" = "Zenith";
    "UNK" = "Unknown";
    "_YV" = "Fujitsu";
    "ENV"="Envision"      
    "HSD"="Hanns.G"
}
if ($wmiMonitorID.ManufacturerName -ne $null)
{
$manuf = $null
$manuf= ([System.Text.Encoding]::ASCII.GetString($wmiMonitorID.ManufacturerName)).Replace("$([char]0x0000)","")			 			
    if ($ManufacturerHashTable["$manuf"])
    {
        $ManufacturerHashTable["$manuf"]
    }
    else
    {
        $manuf
    }	
}

}

[scriptblock]$SBMonPCode=
{
if ($wmiMonitorID.ProductCodeID -ne $null)
{		
	$dispproduct = $null
    $dispproduct=([System.Text.Encoding]::ASCII.GetString($wmiMonitorID.ProductCodeID)).Replace("$([char]0x0000)","")			
	$dispproduct		
}

}

[scriptblock]$SbMonSn=
{
if ($wmiMonitorID.SerialNumberID -ne $null)
{		
    $dispserial = $null
    $dispserial=([System.Text.Encoding]::ASCII.GetString($wmiMonitorID.SerialNumberID)).Replace("$([char]0x0000)","")			
    $dispserial		
}

}

[scriptblock]$SbMonName=
{
if ($wmiMonitorID.UserFriendlyName -ne $null)
{
	$dispname  = $null
	$dispname=([System.Text.Encoding]::ASCII.GetString($wmiMonitorID.UserFriendlyName)).Replace("$([char]0x0000)","")		
    $dispname
}

}

[scriptblock]$SbNetworkAdapters=
{
$dispNetAdap=$Win32_NetworkAdapterConfiguration | Select-Object -Property Description,MACAddress,IPAddress,DHCPServer,DefaultIPGateway,DNSServerSearchOrder
$dispNetAdap
}

[scriptblock]$SbNetPhysAdapCount=
{
$Count=0
$Win32_NetworkAdapter | foreach {if ($_.physicaladapter){$count++}}
$count
}

[scriptblock]$SbPrinters=
{    
#$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor                                                          
$dispPrinter=$Win32_Printer | foreach {
    $Property=@{
    Name=$_.Name
    DriverName=$_.DriverName
    Local=$_.Local
    ShareName=$_.ShareName
    }
    $TmpObj=New-Object psobject -Property $Property
    $TmpObj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Printers.Printer")
    $TmpObj
}
$dispPrinter

}
[scriptblock]$SbUsbConPrCount=
{                                                     
$count=0
$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor
$dispPrinter | foreach {
    if (($_.portname -match "Usb") -and ($_.local -eq $True) -and ($_.workOffline -eq $false))
    {
        $Count++                                                   
    }
                                                                                                                
}

 $count
}

[scriptblock]$SbIsPrintServer=
{
                                                     
$IsPrintServer=$false
$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor
$dispPrinter | foreach {
    if (($_.portname -match "Usb") -and ($_.local -eq $True) -and ($_.workOffline -eq $false))
    {                                                     
        if ($_.shared -eq $true)
        {
            $IsPrintServer=$True
        }
                                                            
    }
                                                                                                           
}

$IsPrintServer                                                    

}

[scriptblock]$SbUsbConPrOnline=
{
$ObjUsbConnectPrinters=@()
$dispPrinter=$Win32_Printer | Select-Object -Property Name,DriverName,Network,Local,PortName,WorkOffline,Published,Shared,ShareName,Direct,PrinterStatus,PrintProcessor
$dispPrinter | foreach {
    if (($_.portname -match "Usb") -and ($_.local -eq $True) -and ($_.workOffline -eq $false))
    {
        $ObjUsbConnectPrinter=New-Object psobject
        $ObjUsbConnectPrinter | Add-Member -NotePropertyName PrinterName -NotePropertyValue $_.name
        $ObjUsbConnectPrinter | Add-Member -NotePropertyName DriverName -NotePropertyValue $_.DriverName
        $ObjUsbConnectPrinters+=$ObjUsbConnectPrinter
    }
                                                          

}

$ObjUsbConnectPrinters

}

[scriptblock]$SbUsbDevices=
{
$Win32_USBControllerDevice | foreach {[wmi]($_.dependent)} | Select-Object -Property Name
}

[scriptblock]$SbMemoryMaxIns=
{
$MemMaxinsCount=0													
$Win32_PhysicalMemoryArray | foreach {$MemMaxinsCount+=$_.MaxCapacity*1kb}
$MemMaxinsCount
}

[scriptblock]$SBOsProductKey=
{
try{
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
catch{$_}

}

[scriptblock]$SbGetRegistryValue=
{
try{
RegGetValue -key $ReGistryKey -Value $ReGistryValue -GetValue $RegistryValueType -ErrorAction Stop
}
catch{$_}
}

[ScriptBlock]$SbSoftwareList=
{
try{
$Object =@()
$excludeArray = ("Security Update for Windows",
"Update for Windows",
"Update for Microsoft .NET",
"Security Update for Microsoft",
"Hotfix for Windows",
"Hotfix for Microsoft .NET Framework",
"Hotfix for Microsoft Visual Studio 2007 Tools",
"Hotfix",
"Update for Microsoft Office"
)

$GetArch=RegGetValue -key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "PROCESSOR_ARCHITECTURE" -GetValue GetStringValue -ErrorAction Stop 
If($GetArch -eq "AMD64")
{            
    $OSArch='64-bit'
}            
Else
{            
    $OSArch='32-bit'            
}
Switch ($OSArch)
{


 "64-bit"{

$RegKey_64BitApps_64BitOS = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$RegKey_32BitApps_64BitOS = "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
#$RegKey_32BitApps_32BitOS = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"

#############################################################################

# Get SubKey names

$SubKeys = RegEnumKey -key $RegKey_64BitApps_64BitOS -ErrorAction Stop



ForEach ($Name in $SubKeys)
 {

$SubKey = "$RegKey_64BitApps_64BitOS\$Name"

$AppName = RegGetValue -key $SubKey -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Version =RegGetValue -key $SubKey -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Publisher=RegGetValue -key $SubKey -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue
$donotwrite = $false

if($AppName.length -gt "0"){

 Foreach($exclude in $excludeArray) 
    {
        if($AppName.StartsWith($exclude) -eq $TRUE)
        {
            $donotwrite = $true
            break
        }
    }
            if ($donotwrite -eq $false) 
                        {                        
                        $TmpObject="" | Select-Object Appication,Architecture,Version,Publisher
                        $TmpObject.Appication=$AppName
                        $TmpObject.Architecture="64-BIT"
                        $TmpObject.Version=$Version
                        $TmpObject.Publisher=$Publisher
                        $Object += $TmpObject
                        }





}

  }

 

#############################################################################
$SubKeys = RegEnumKey -key $RegKey_32BitApps_64BitOS -ErrorAction Stop

  # Loop Through All Returned SubKEys

  ForEach ($Name in $SubKeys)

  {

    $SubKey = "$RegKey_32BitApps_64BitOS\$Name"

$AppName = RegGetValue -key $SubKey -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Version =RegGetValue -key $SubKey -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Publisher=RegGetValue -key $SubKey -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue

 $donotwrite = $false
         
                             



if($AppName.length -gt "0"){
 Foreach($exclude in $excludeArray) 
                        {
                        if($AppName.StartsWith($exclude) -eq $TRUE)
                            {
                            $donotwrite = $true
                            break
                            }
                        }
            if ($donotwrite -eq $false) 
                        {                        
            $TmpObject="" | Select-Object Appication,Architecture,Version,Publisher
            $TmpObject.Appication=$AppName
            $TmpObject.Architecture="32-BIT"
            $TmpObject.Version=$Version
            $TmpObject.Publisher=$Publisher
            $Object += $TmpObject
                        }
           }

 

    }

 



 

} #End of 64 Bit

######################################################################################

###########################################################################################

 

"32-bit"{

$RegKey_32BitApps_32BitOS = "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall"

#############################################################################

# Get SubKey names

$SubKeys = RegEnumKey -key $RegKey_32BitApps_32BitOS -ErrorAction Stop
# Loop Through All Returned SubKEys
ForEach ($Name in $SubKeys)

  {
$SubKey = "$RegKey_32BitApps_32BitOS\$Name"
$AppName = RegGetValue -key $SubKey -Value "DisplayName" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Version =RegGetValue -key $SubKey -Value "DisplayVersion" -GetValue GetStringValue -ErrorAction SilentlyContinue
$Publisher=RegGetValue -key $SubKey -Value "Publisher" -GetValue GetStringValue -ErrorAction SilentlyContinue

if($AppName.length -gt "0"){

$TmpObject="" | Select-Object Appication,Architecture,Version,Publisher
$TmpObject.Appication=$AppName
$TmpObject.Architecture="32-BIT"
$TmpObject.Version=$Version
$TmpObject.Publisher=$Publisher

$Object+= $TmpObject
           }

  }

}#End of 32 bit

} # End of Switch

$object 
}
catch
    {
    $_
    }
}
#################################################################################################################################
#EndScriptBlock 
#Block Function
#Registry function

function RegGetValue
{
[CmdletBinding()]
param(
[parameter(Mandatory=$true)]
[string]$Key,
[parameter(Mandatory=$true)]
[string]$Value,
[parameter(Mandatory=$true)]
[ValidateSet("GetStringValue","GetBinaryValue","GetDWORDValue")]
[string]$GetValue
)
if ($stdregprov -eq $null)
{
    Write-Error "Variable StdRegProv Null"
}
$ResultProp=@{
"GetStringValue"="Svalue"
"GetBinaryValue"="Uvalue"
"GetDWORDValue"="UValue"
}
$ErrorCode=@{
"1"="Value doesn't exist"
"2"="Key doesn't exist"
"2147749893"="Wrong value type"
"5"="Access Denied"
"6"="Wrong Key String"
}
$hk=@{

"HKEY_CLASSES_ROOT"=2147483648
"HKEY_CURRENT_USER"=2147483649
"HKEY_LOCAL_MACHINE"=2147483650
"HKEY_USERS"=2147483651
"HKEY_CURRENT_CONFIG"=2147483653

}
if($Key -match "(.+?)\\(.+)")
{
    if ($hk.Keys -eq $matches[1])
    {
        $RootHive=$hk[$matches[1]]
        $KeyString=$matches[2]
        $StdRegProvResult=$StdRegProv | Invoke-WmiMethod -Name $GetValue -ArgumentList $RootHive,$KeyString,$Value
    }
    else
    {
        Write-Error "$($matches[1]) Does not belong to the set $($hk.Keys)" -ErrorAction Stop
    }
    if ($StdRegProvResult.returnvalue -ne 0)
    {
        if ($ErrorCode["$($StdRegProvResult.returnvalue)"] -ne $null)
        {
            $er=$ErrorCode["$($StdRegProvResult.returnvalue)"]
            Write-Error "$Er! Key $Key Value $Value "
        }
        else
        {
            $er=$StdRegProvResult.returnvalue
            Write-Error "$GetValue return $Er! Key $Key Value $Value "
        }
        
    }
    else
    {
        $StdRegProvResult.($ResultProp["$GetValue"])
    }
}
else
{
    Write-Error "$Key not valid"
}

}

function RegEnumKey
{
[CmdletBinding()]
param(
[parameter(Mandatory=$true)]
[string]$Key
)
$ErrorActionPreference="Stop"
if ($stdregprov -eq $null)
{
    Write-Error "Variable StdRegProv Null"
}
$ErrorCode=@{
"1"="Value doesn't exist"
"2"="Key doesn't exist"
"5"="Access Denied"
"6"="Wrong Key String"
}
$hk=@{

"HKEY_CLASSES_ROOT"=2147483648
"HKEY_CURRENT_USER"=2147483649
"HKEY_LOCAL_MACHINE"=2147483650
"HKEY_USERS"=2147483651
"HKEY_CURRENT_CONFIG"=2147483653
}
if($Key -match "(.+?)\\(.+)")
{
$StdRegProvResult=$StdRegProv.EnumKey($hk[$matches[1]],$matches[2])
    if ($StdRegProvResult.returnvalue -ne 0)
    {
        if ($ErrorCode["$($StdRegProvResult.returnvalue)"] -ne $null)
        {
            $er=$ErrorCode["$($StdRegProvResult.returnvalue)"]
        }
        else
        {
            $er=$StdRegProvResult.returnvalue
        }
    Write-Error "$Er key $Key"
        
    }
    else
    {
        $StdRegProvResult.snames
    }
}
else
{
    Write-Error "$Key not valid"
}

}
#End Registry function 
function GetHddSmart
{
	function ConvertTo-Hex ( $DEC ) {
		'{0:x2}' -f [int]$DEC
	}
	function ConvertTo-Dec ( $HEX ) {
		[Convert]::ToInt32( $HEX, 16 )
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
			'c6' { 'Offline Uncorrectable Sector Count (Uncorrectable Sector Count)' }
			'c7' { 'UltraDMA CRC Error Count' }
			'c8' { 'Write Error Rate (MultiZone Error Rate)' }
			'c9' { 'Soft Read Error Rate' }
			'cb' { 'Run Out Cancel' }
			'cа' { 'Data Address Mark Error' }
			'dc' { 'Disk Shift' }
			'e1' { 'Load/Unload Cycle Count' }
			'e2' { 'Load ''In''-time' }
			'e3' { 'Torque Amplification Count' }
			'e4' { 'Power-Off Retract Cycle' }
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
$hdddev=$Win32_DiskDrive | Select-Object Model,Size,MediaType,InterfaceType,FirmwareRevision,SerialNumber,PNPDeviceID
$hdddev | foreach {
    $PnpDev.Add($($_.pnpdeviceid -replace "\\","\\"),$_)
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
        $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name  PredictFailure -Value 'Not supported'
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
				            $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name $( Get-AttributeDescription $Attribute) -Value $Value
                        }
			        }
			        $pByte = $Byte
                }
        
    }
    else
    {
        $PnpDev[$PnpDevid] | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Not supported' 
    }
    $HddSmart=$PnpDev[$PnpDevid]
    $WarningThreshold=@{
    "Temperature"=46,54
    "Reallocated Sector Count"=1,10
    }
    $CriticalThreshold=@{
    "Temperature"=55
    "Reallocated Sector Count"=11
    }
        $HddWarning=$False
        $HddCritical=$False
        $HddSmart | Get-Member | foreach {
            $Property=$_.name
            if ($WarningThreshold[$Property])
            {
                $MinWarningThreshold=$WarningThreshold[$Property][0]
                $MaxWarningThreshold=$WarningThreshold[$Property][1]
                    if ($HddSmart.$Property -le $MaxWarningThreshold -and $HddSmart.$Property -ge $MinWarningThreshold)
                    {
                        $HddWarning=$true
                    }
            }
            

            if ($CriticalThreshold[$Property])
            {
                $MinCriticalThreshold=$CriticalThreshold[$Property]
                    if($HddSmart.$Property -ge $MinCriticalThreshold)
                    {
                        $HddCritical=$true
                    } 
            }
              
            
        #End Foreach
        }
    if ($HddSmart.smartstatus -ne "Not supported")
    {
        if ($HddWarning)
        {
            $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Warning' 
        }
        elseif($HddCritical -or $HddSmart.PredictFailure)
        {
            $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Critical'   
        }
        else
        {
            $HddSmart | Add-Member -MemberType NoteProperty -Name SmartStatus -Value 'Ok'   
        }
    }
$HddSmart
#End Foreach
}
}

####################################################
function StartRunspaceJob
{
    param(
    $WmiVariable,
    $ScriptBlock,
    $ComputerName,
    $Prop
    )
    $ParamList=@{}
    $WmiVariable | Get-Member -MemberType NoteProperty  | foreach {$ParamList.Add($_.name,$WmiVariable.($_.name))}
    if ($PropertyParams[$prop] | Where-Object {$_.keys -eq "RunspaceImportVariable"})
    {
    $AddParam=@()
    $AddParam+=($PropertyParams[$prop] | Where-Object {$_.keys -eq "RunspaceImportVariable"}).RunspaceImportVariable
    $AddParam | foreach {
        if ($_ -match "^\$")
        {
            $ParamList.Add($($_ -replace "\$",""),$(get-variable -name $($_ -replace "\$","") -ValueOnly))
        }
        else
        {
            Write-Error "RunspaceImportVariable Wrong param $_. Check FunctionConfig" -ErrorAction Stop
        }
    
    }

    }

    $PowerShell = [powershell]::Create()
    [void]$PowerShell.AddScript(
    $ScriptBlock
    )
    [void]$PowerShell.AddParameters($ParamList)
    $PowerShell.Runspacepool = $RunspacePool
    $State = $PowerShell.BeginInvoke()
    $temp = '' | Select PSJobTypeName,PowerShell,State,Location,StartTime,Property,Runspace
    $temp.PSJobTypeName="RunspaceJob"
    $temp.powershell=$PowerShell
    $temp.state=$State
    $temp.location=$Computername
    $temp.StartTime=get-date
    $temp.Property=$Prop
    $temp.runspace=$Runspace
    $temp
}

function GetWmi{
param(
$ComputerName,
$WmiParamArray
)
$Count=0
$WmiParamArray | foreach {
    $WmiParam=$_
    if ($Credential -ne $null)
    {  
        if (!($LocalComputer -eq $ComputerName))
        {   
            if (!($WmiParam["Credential"]))
            {
                $WmiParam.Add("Credential",$Credential)
            }   
        }    
    }
    if ($jobs.count -ge $MaxJob)
    {
        do{
            $repeat=$true
            GetJob
                if ($Jobs.Count -lt $MaxJob)
                {
                    $repeat=$false
                }
                else
                {
                    Start-Sleep -Milliseconds 20
                }   
        }while($repeat)
    }
    $RemoveClass=$null
    if ($WmiParam['Query'])
    {
        $RemoveClass=$WmiParam['Class']
        $WmiParam.Remove("Class")
    }
    if ($WmiParam['class'])
    {
        Write-Verbose "$Computername Start Job Get-WmiObject -Class $($WmiParam['class']) -NameSpace $($WmiParam['NameSpace'])"
    }
    else
    {
        Write-Verbose "$Computername Start Job Get-WmiObject -Query $($WmiParam['Query']) -NameSpace $($WmiParam['NameSpace'])"
    }
    $TmpWmiJob=Get-WmiObject @WmiParam -computername $ComputerName -ErrorAction Stop -AsJob   
    if ($?)
    {
        $temp = '' | Select-Object PSJobTypeName,WmiJob,StartTime,Location,Class,Query
        $temp.PSJobTypeName="WmiJob"
        $temp.WmiJob=$TmpWmiJob
        $temp.StartTime=Get-Date
        $Temp.Location=$ComputerName
            if ($RemoveClass)
            {
                $Temp.Class=$RemoveClass
                $Temp.Query=$true
            }
            else
            {
                $Temp.Class=$WmiParam['Class']
                $Temp.Query=$False
            }
    
        [void]$Jobs.Add($temp) 
        }

    if ($WmiParam['Query'])
    {
        $WmiParam.Add("Class",$RemoveClass)
    }
    $Count++
    if ($Count -eq $WmiParamArray.count)
    {
        Write-Verbose "$ComputerName All Wmi request completed"
        [void]$GetWmicompletedForComputers.Add($ComputerName)   
    }

#End Foreach
}

}

function WrErr($Err,$Job)
{
try{

if ($Job -eq $null)
{
    Write-Error "$Computername Job variable null" -ErrorAction Stop
}
if($tmperr=$Global:ErrorResult | Where-Object {$_.computername -eq $Job.location})
{
    if ($tmperr.warning -ne $err.Exception.Message)
    {
        Write-Warning  "$($Job.location) $($err.Exception.Message)"
        $tmperr.warning=$tmperr.warning+","+$err.Exception.Message
    }
}
else
{
    Write-Warning  "$($Job.location) $($err.Exception.Message)"
    $ErTmp="" | select ComputerName,Warning,Error
    $ErTmp.ComputerName=$Job.location
    $ErTmp.Warning=$err.Exception.Message
    $ErTmp.Error=$err
    $Global:ErrorResult+=$ErTmp
}
if ($Job.PSJobTypeName -eq "RunspaceJob")
{
    $Job.powershell.dispose()
    $Job.State = $null
    $Job.powershell = $null
}
$RemoveJobs=$jobs | Where-Object {$_.location -eq $Job.location}
$RemoveJobs  | foreach {$Jobs.Remove($_)}
}catch{
$Jobs.Remove($Job)
}

}

function GetJob
{
try
{
    #Write-Verbose "getjob"
    #Start-Sleep -Milliseconds 500
    #Failed Job
    $AllFailedWmiJobs=$Jobs | Where-Object  {$_.WmiJob.State -eq "Failed"}
    if ($AllFailedWmiJobs -ne $null)
    {
        $AllFailedWmiJobs | foreach {
            try
            {
                $Job=$_.WmiJob
                $TmpErRec=$Job | Receive-Job -ErrorAction Stop
                    if ($TmpErRec -eq $null)
                    {
                        if ($VerbosePreference -eq "Continue")
                        {
                            Write-Warning "$($Job.location) $($_.Class) JobState Failed Get-WmiObject return Null Value"
                        }
            
                    }
                Remove-Job $Job
                $Jobs.Remove($_)
            } 
            catch 
            {
                WrErr -Err $_ -Job $Job
            }
        # End Foreach
        }
    }

    #Completed Job
    $AllCompletedJobs=$Jobs | Where-Object {$_.WmiJob.State -eq "Completed"} 
    #Completed Runspace Job
    $AllRunspaceCompletedJob=$jobs | Where-Object {$_.state.isCompleted}
    if ($AllRunspaceCompletedJob -ne $null)
    {
        $AllRunspaceCompletedJob | foreach {
            $Job=$_
            $TmpRes=$_.powershell.EndInvoke($_.State)
            if($_.powershell.HadErrors -eq $true)
            {
                if ($TmpRes.count -eq 0)
                {
                    Write-Error "Scriptblock HadErrors, use try{}catch{} in the ScriptBlock to find out the details" -ErrorAction Stop
                }
                elseif ($TmpRes[0].GetType().name -eq "ErrorRecord")
                {
                    Write-Error $TmpRes[0] -ErrorAction Stop
                }
                else
                {
                    Write-Error "Unknown Error" -ErrorAction Stop
                }
            }
            elseif($TmpRes[0] -ne $null)
            {
                    if ($TmpRes[0].GetType().name -eq "ErrorRecord")
                    {
                        Write-Error $TmpRes[0] -ErrorAction Stop
                    }
                Write-Verbose "$($Job.location) RunspaceJob for Property $($Job.property) Completed"
                write-verbose "$($Job.location) Add to result $($Job.property)=[Scriptblock]$(($PropertyParams[$Job.property] | Where-Object {$_.Scriptblock}).ScriptBlock)"
                $HashtableResult[$Job.location].($Job.property)=$TmpRes
                $_.powershell.dispose()
                $_.State = $null
                $_.powershell = $null
                $Jobs.Remove($Job)
                
            }
            else
            {
                Write-Error "Scriptblock return empty value" -ErrorAction Stop
            }
    
        # End Foreach
        }
    }
    if($AllCompletedJobs -ne $null)
    {
        $AllCompletedJobs | foreach {
            $Job=$_.WmiJob
            $Computername=$_.location
            $GetWmi=@()
            $GetWmi+=Receive-Job -Job $Job -ErrorAction Stop
            if ($GetWmi.Count -eq 0 -or $GetWmi[0] -eq $null)
            {
                if ($VerbosePreference -eq "Continue")
                {
                    Write-Warning -Message "$Computername $($_.Class) Get-Wmiobject return empty value.."
                }
            }
            else
            {
                    if ($_.Query)
                    {
                        $GwmiClass=$_.Class
                    }
                    else
                    {
                        $GwmiClass=$GetWmi[0].__CLASS
                    }
                    
                    if ($GetWmi.Count -eq 1)
                    {
                        $GetWmi=$Getwmi[0]
                    }
                Write-Verbose "$Computername Receive-Job $GwmiClass Completed"
                $HashtableWMi[$ComputerName].$GwmiClass=$GetWmi
            }
        
            Remove-Job $Job -Force
            $Jobs.Remove($_)
    
        # End Foreach
        }

    }
    #Create Result
    $TmpGetWmicompletedForComputers=$GetWmicompletedForComputers.clone()
    $TmpGetWmicompletedForComputers | foreach {
        $ComputerName=$_
        if (!($Jobs | Where-Object {$_.Location -eq $ComputerName}))
        {
            if (!($Global:ErrorResult | Where-Object {$_.computername -eq $ComputerName}))
            {
                #Create Variable
                $HashtableWMi[$computername] | Get-Member -MemberType NoteProperty | foreach {New-Variable -Name $_.Name -Value $HashtableWMi[$computername].$($_.Name)}
            
                $AllProperties | foreach{
                    $Property=$_
                    $Keys=$PropertyParams[$property] | foreach {$_.keys}
                    $ParamProperty=($PropertyParams[$Property] | Where-Object {$_.Property}).Property
                    $ParamScriptblock=($PropertyParams[$Property] | Where-Object {$_.Scriptblock}).ScriptBlock
                    $Class=($PropertyParams[$Property] | Where-Object {$_.class}).class
                    if ($Keys -eq "UseRunspace")
                    {
                        if ($HashtableResult[$ComputerName].$Property -eq $null)
                        {
                            #Add param to Runspace scriptblock
                            $AddParam=@()
                            #Add all wmi variable
                            $HashtableWMi[$computername] | Get-Member -MemberType NoteProperty | foreach {$AddParam+=('$'+$_.name)}
                                if ($Keys -eq "RunspaceImportVariable")
                                {
                                    #Add all RunspaceImportVariable
                                    $AddParam+=($PropertyParams[$property] | Where-Object {$_.runspaceimportvariable}).runspaceimportvariable
                                }
                            Write-Verbose -Message "$ComputerName Edit ScriptBlock [ScriptBlock]$($ParamScriptblock)"
                            $ScriptBlockParam = $ExecutionContext.InvokeCommand.NewScriptBlock("param($($AddParam -Join ", "))`r`n"+$(get-variable -name $($ParamScriptblock -replace "\$","") -ValueOnly).ToString())
                            Write-Verbose "$ComputerName StartRunspaceJob for Property $Property"
                            StartRunspaceJob -WmiVariable $HashtableWMi[$computername] -ScriptBlock $ScriptBlockParam -ComputerName $ComputerName -Prop $Property | foreach {[void]$Jobs.Add($_);}
                        
                            #It is mandatory to use this delay otherwise there are run-time errors
                            Start-Sleep -Milliseconds 200
                        
                        }
                    
                    }
                    if ($HashtableResult[$ComputerName].$Property -eq $null)
                    {
                            if ($ParamProperty)
                            {
                                Write-Verbose ("$ComputerName Add to result $Property=$"+"$Class.$ParamProperty")
                                $WmiVariables=Get-Variable -Name $Class -ValueOnly
                                    if ($WmiVariables.count -gt 1)
                                    {
                                        $ResultParamProperty=$WmiVariables | foreach {$_.$ParamProperty}
                                    }
                                    else
                                    {
                                        $ResultParamProperty=$WmiVariables.$ParamProperty
                                    }
                                $HashtableResult[$ComputerName].$Property=$ResultParamProperty
                            }
                            elseif ($ParamScriptblock -and !($Keys -eq "UseRunspace" ))
                            {
                                Write-Verbose "$ComputerName Add to result $Property= [Scriptblock]$($ParamScriptblock)"
                                try
                                    {
                                    $HashtableResult[$ComputerName].$Property=&$(get-variable -name $($ParamScriptblock -replace "\$","") -ValueOnly)
                                    }
                                catch
                                    {
                                    Write-Error -Message "Check Scriptblock [ScriptBlock]$ParamScriptblock $($_.Exception.message) $($_.InvocationInfo.PositionMessage)" -ErrorAction stop
                                    }
                            }
                            elseif (!($Keys -eq "UseRunspace" ))
                            {
                                Write-Verbose ("$ComputerName Add to result $Property=$"+"$Class")
                                $WmiVariables=Get-Variable -Name $Class -ValueOnly
                                $ResultParamProperty=$WmiVariables
                                $HashtableResult[$ComputerName].$Property=$ResultParamProperty
                            }
                    
                   
                    }
                        
                    #End Foreach
                }
    
                #Remove Variable
                $HashtableWMi[$computername] | Get-Member -MemberType NoteProperty | foreach {Remove-Variable -Name $_.name -Force}
                    if (!($Jobs | Where-Object {$_.Location -eq $ComputerName}))
                    {
                        Write-Verbose -Message "$ComputerName All Job Completed"
                        $Global:Result+=$HashtableResult[$ComputerName]
                            if ($UpdateFormatData)
                            {
                                CreateFormatPs1xml -ForObject $HashtableResult[$ComputerName] -ErrorAction Stop
                                Update-FormatData -PrependPath $($env:TEMP+"\SystemInfoAutoformat.ps1xml") -ErrorAction SilentlyContinue
                                Set-Variable -Name UpdateFormatData -Value $false -Scope 1 -Force
                            }
                        $HashtableResult[$ComputerName].psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.AutoFormatObject") 
                        $HashtableResult[$ComputerName]
                        $GetWmicompletedForComputers.remove($ComputerName)
                    }
            }

        
        
        }
    # End Foreach
    }



    #Timeout Job
    $AllTimeOutJob=$Jobs | Where-Object {(New-TimeSpan -start $_.StartTime).TotalSeconds -gt $JobTimeOut}
    if ($AllTimeOutJob -ne $null)
    {
        $AllTimeOutJob | foreach {
            try
            {
                $Job=$_
                Write-Error -Message "Timeout expired" -ErrorAction Stop
            }
            catch
            {
                WrErr -Err $_ -Job $Job
            }

        }
    }

}
catch
{
    WrErr -Err $_ -Job $Job
}

# End Function
}

function CreateFormatPs1xml
{
[CmdletBinding()]
param(
$ForObject
)
$ConvertToGb="MemoryTotal","MemoryMaxIns","MemoryFree","MemoryAvailable","VideoRam"
$FormatTableFor="PSCustomObject","ManagementObject"
[string]$XmlFormatList=''
$DollarUnder='$_'
$AllProperties | foreach{
    $Property=$_
    if ($Forobject.$Property.count -gt 1)
    {
        $ForObjectProperty=$Forobject.$Property[0]
    }
    else
    {
        $ForObjectProperty=$Forobject.$Property
    }
    if ($ForObjectProperty -eq $null)
    {
        $XmlFormatList+="
            <ListItem>
                <PropertyName>$Property</PropertyName>
            </ListItem>"
    }
    elseif($ForObject.HddSmart)
    {
        $XmlFormatList+="
        <ListItem>
        <Label>$Property</Label>
            <ScriptBlock> 
                $DollarUnder.$Property | fl | out-string
            </ScriptBlock>
        </ListItem>"
    }
    elseif ($FormatTableFor -eq ($ForObjectProperty).GetType().name)
    {
        $XmlFormatList+="
        <ListItem>
        <Label>$Property</Label>
            <ScriptBlock> 
                $DollarUnder.$Property | ft -autosize | out-string
            </ScriptBlock>
        </ListItem>"
    }
    elseif ($ConvertToGb -eq $Property)
    {
               
        $XmlFormatList+="<ListItem>
        <Label>$Property</Label>
            <ScriptBlock>
		    [string]('{0:N1}' -f ($DollarUnder.$property/1gb))+'Gb'
            </ScriptBlock>
        </ListItem>"
                    
    }
    else
    {
        $XmlFormatList+="
        <ListItem>
            <PropertyName>$Property</PropertyName>
        </ListItem>"
    }
# End Foreach
}

#$XmlFormatList
$XmlAutoFormat='<?xml version="1.0" encoding="utf-8" ?>'
$XmlAutoFormat+="
<Configuration>
    <ViewDefinitions>
    <View>
        <Name>Default</Name>
            <ViewSelectedBy>
                <TypeName>ModuleSystemInfo.Systeminfo.AutoFormatObject</TypeName>
            </ViewSelectedBy>
    <ListControl>
        <ListEntries>
            <ListEntry>
                <ListItems>
                <ListItem>
                    <PropertyName>ComputerName</PropertyName>
                </ListItem>
                $XmlFormatList
                </ListItems>
            </ListEntry>
        </ListEntries>
    </ListControl>
    </View>
    </ViewDefinitions>
</Configuration>"
Write-Verbose "Create ps1xml file $($env:TEMP+"\SystemInfoAutoformat.ps1xml")"
$XmlAutoFormat | Out-File -FilePath $($env:TEMP+"\SystemInfoAutoformat.ps1xml") -Force -ErrorAction Stop
#End Function
}

Function ParseParam
{
param(
[parameter(Mandatory=$true)]
[string]$ParamString,
[String]$Property
)
$PermitParams="Class","ScriptBlock","UseRunspace","RunspaceImportVariable","Property","Query","Namespace"
$ArrayHashTableParam=@()
$ArrayParamString=(((($ParamString -replace "\s+"," ") -replace "\s+$","") -replace "^-"," -") -replace " -"," --") -split "\s-"
$ArrayParamString | foreach {
    $HashTableParam=@{}
    if ($_ -match "^-(.+?)\s(.+)$")
    {
        $ParseParam=$Matches[1]
        $ParseValue=$Matches[2]
            if ($ParseValue -match ",")
            {
                $ArrayParseValue=$ParseValue -split ","
                $ParseValue=$ArrayParseValue
            }
        $HashTableParam.Add($ParseParam,$ParseValue)
        $ArrayHashTableParam+=$HashTableParam
    
    }
    elseif ($_ -match "-(.+\S)")
    {
        $HashTableParam.Add($Matches[1],$null)        
        $ArrayHashTableParam+=$HashTableParam
    }
# End Foreach
}
$DifObj=$ArrayHashTableParam | foreach {$_.keys}
$CompareParam=Compare-Object -ReferenceObject $PermitParams -DifferenceObject $DifObj
if ($CompareParam | where-object {$_.sideindicator -eq "=>"})
{
    Write-Error "$Property Parameter -$(($CompareParam | Where-Object {$_.SideIndicator -eq "=>"}).inputobject) not allowed. Check FunctionConfig" -ErrorAction Stop
}
$ArrayHashTableParam

#End Function
}

#End Block Function
#####################################################################################################
$TestAdminUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin=$TestAdminUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
$CurrentExecutionPolicy=Get-ExecutionPolicy
$ExecutionPolicyChanged=$false
if (!($RequiredExecutionPolicy -eq $CurrentExecutionPolicy))
{
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -Confirm:$false 
        if ($?)
        {
            $ExecutionPolicyChanged=$true
        }
        else
        {
            Write-Warning "Formatting objects does not work. Run the command Set-ExecutionPolicy -ExecutionPolicy RemoteSigned and retry now"
        }    
}
if ($PSBoundParameters['ShowStatistics'].ispresent)
{
    $BeginFunction=get-date
}
if ($PSBoundParameters['Credential'])
{
    if (!($Credential.gettype().name -eq "PSCredential"))
    {
        $Credential=Get-Credential $Credential
    }    
}
#Clear Old Job
Write-Verbose "Clear old Job"
Get-Job | where-object {$_.PSJobTypeName -eq "wmijob"} | Remove-Job -Force
#Check registry param
try
{
    if ($PSBoundParameters["RegistryKey"] -ne $null -or $PSBoundParameters["RegistryValue"] -ne $null -or $PSBoundParameters["RegistryValueType"] -ne $null)
    {
        if ($PSBoundParameters["RegistryKey"] -eq $null)   
        {
            $RegistryKey=Read-Host -Prompt "RegistryKey"
        }
        if ($PSBoundParameters["RegistryValue"] -eq $null)
        {
            $RegistryValue=Read-Host -Prompt "RegistryValue"
        }
        if ($PSBoundParameters["RegistryValueType"] -eq $null)
        {
            $RegistryValueType=Read-Host -Prompt "RegistryValueType"
        }
    
    $Properties+="RegistryValue"
    }

}
catch
{
    Write-Error "$_" -ErrorAction Stop
} 

#Collection all Properties
$AllPropertiesSwitch=@()
$AllPropertiesSwitch+=$PSBoundParameters.Keys | foreach {
    if ($PSBoundParameters[$_].ispresent -and !($ExcludeParam -eq $_))
    {
        $SwitchConfig[$_]        
    }

}
if ($AllPropertiesSwitch[0] -eq $Null -and $Properties -eq $null)
{
    $AllPropertiesSwitch=$DefaultInfoConfig   
}
$AllProperties+=$AllPropertiesSwitch+$Properties
if ($AllProperties.GetType().name -ne "string")
{
    $AllProperties=0..$AllProperties.Count | foreach {if ($AllProperties[$_] -ne $null){$AllProperties[$_]}}
    $AllProperties = $AllProperties | Select-Object -Unique
}
if ($AllProperties -match "\*")
{
    Write-Verbose "Property: $($FunctionConfig.Keys)"
    $AllProperties=$FunctionConfig.Keys -ne "RegistryValue"
}
else
{
    Write-Verbose "Property: $AllProperties"
}

#Parse FunctionConfig
$PropertyParams=@{}
$AllProperties | foreach {
    $FunctionProperty=$_
    $ArrayHashTableParam=@()
    if ($FunctionConfig[$FunctionProperty] -eq $Null)
    {
        Write-Error "Property $FunctionProperty not found in $('$FunctionConfig')" -ErrorAction Stop
    }
    $ArrayHashTableParam+=ParseParam -ParamString $FunctionConfig[$FunctionProperty] -Property $FunctionProperty
    if ($QueryTmp=$($ArrayHashTableParam | where-object {$_.Query}))
    {
            if ($QueryTmp.Query -match ".+from\s(.+?)\s")
            {
                $TmpClass="Query_"+$Matches[1]+"_"+$FunctionProperty
            }
            else
            {
                Write-Error "Wrong query $($QueryTmp.Query)! Check query param." -ErrorAction Stop
            }
            if ($TmpClassHash=$ArrayHashTableParam | where-object {$_.class})
            {
                $TmpArrayClass=@()
                $TmpArrayClass+=$TmpClassHash.Class
                $TmpArrayClass+=$TmpClass
                $TmpClassHash.Class=$TmpArrayClass
            }
            else
            {
                $TmpClassHash=@{
                Class="$TmpClass"
                }
                $ArrayHashTableParam+=$TmpClassHash
            }
    
    }

    if ($($ArrayHashTableParam | where-object {$_.class}) -ne $null)
    {
        $PropertyParams.Add($FunctionProperty,$ArrayHashTableParam)
    }
    else
    {
        Write-Error "$FunctionProperty missing -Сlass parameter. Check FunctionConfig" -ErrorAction Stop
    }
# End Foreach
}

#Check ScriptBlock param
$PropertyParams.keys | foreach {
    try
    {
        $UserProperty=$_
        $ParamHashTable=$PropertyParams[$UserProperty]
        $ParamScriptblock=$ParamHashTable | Where-Object {$_.keys -eq "Scriptblock"}
        if ($ParamScriptblock)
        {
            if ($ParamScriptblock.scriptblock -eq $null)
            {
                Write-Error "parameter -ScriptBlock is empty. Check FunctionConfig" -ErrorAction Stop
            }
            else
            {
                if ($ParamScriptblock.scriptblock -match "\$.+\S")
                {
                        if((get-variable -Name $($ParamScriptblock.scriptblock -replace "\$","") -ValueOnly -ErrorAction Stop).GetType().Name -ne "Scriptblock")
                        {
                            Write-Error "Wrong variable type $($ParamScriptblock.scriptblock). Check FunctionConfig, Use [Scriptblock]" -ErrorAction Stop
                        }
    
                }
                else
                {
                    Write-Error "Wrong -Scriptblock variable $($ParamScriptblock.scriptblock). Check FunctionConfig" -ErrorAction Stop
                }
            }
    

        }
    }
    catch
    {
        Write-Error "$UserProperty $($_.Exception.message)" -ErrorAction Stop
    }    
# End Foreach
}
#Create wmi param
$WmiParamArray=@()
$PropertyParams.Keys | foreach {$PropertyParams[$_]} | foreach {$_.class} | Sort-Object -Unique | foreach {
    $Query=$null
    $WmiParam=@{}
    $FakeClass=$_
    $Class=$_

    if ($Class -match "^Query_(.+)?_(.+)")
    {
        $Class=$Matches[1]
        $Query=($PropertyParams[$Matches[2]] | Where-Object {$_.query}).query
    }
    if ($ManualNamespace[$Class])
    {
        $ManualNamespaceParams=ParseParam -ParamString $($ManualNamespace[$Class])
        $ManualNamespaceParamNamespace= $ManualNamespaceParams | Where-Object {$_.namespace}
        $ManualNamespaceParamQuery= $ManualNamespaceParams | Where-Object {$_.Query}
            if ($ManualNamespaceParamNamespace)
            {
                $Namespace=$ManualNamespaceParamNamespace["Namespace"]
            }
            if ($ManualNamespaceParamQuery -and $query -eq $null)
            {
                $Query=$ManualNamespaceParamQuery["Query"]
            }   
    
    }
    else
    {
        try
        {
            if ((Get-WmiObject -query "SELECT * FROM meta_class WHERE __class = '$Class'").__NAMESPACE -eq "ROOT\cimv2")
            {
                $Namespace="ROOT\cimv2"
            }
            else
            {
                Write-Error 'Cannot retrieve Namespace use $ManualNamespace hashtable' -ErrorAction Stop
            } 
        }
        catch
        {
            Write-Error "Cannot retrieve Namespace for class $Class check Functionconfig or use hashtable $('$ManualNamespace') " -ErrorAction Stop
        }
    }
    $WmiParam.Add("Class",$FakeClass)
    $WmiParam.Add("Namespace",$Namespace)
    if ($Query)
    {
        $WmiParam.Add("Query",$Query)
        $ManualNamespaceParamQuery=$Null
    }
    if ($WmiParam.class -ne $Null -and $WmiParam.Namespace -ne $Null)
    {
        $WmiParamArray+=$WmiParam
    }
    else
    {
        Write-Error "Class or Namspace not found" -ErrorAction Stop
    }
#End Foreach
}

#$WmiParamArray
#$PropertyParams

$OpenRunspace=$false
if (($PropertyParams.keys | foreach {$PropertyParams[$_]} | foreach {$_.keys}) -eq "UseRunspace")
{
    $OpenRunspace=$true
}
    
#Import function to runspace
$RunspaceImportFunction="RegGetValue","RegEnumKey"
if ($OpenRunspace)
{
    Write-Verbose "Use Runspace"
    $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    Get-Command -CommandType Function -Name $RunspaceImportFunction | foreach {
        $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $_.name, $_.Definition
        $SessionState.Commands.Add($SessionStateFunction)
    }
        if ($?)
        {
            Write-Verbose "Runspace Commands Add Successfully"
        } 
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1,$MaxJob,$SessionState,$Host)
    $RunspacePool.Open()
}


#Remove old ps1xml file
if (Test-Path $($env:TEMP+"\SystemInfoAutoformat.ps1xml"))
{
    Write-Verbose "Remove ps1xml file $($env:TEMP+"\SystemInfoAutoformat.ps1xml")"
    Remove-Item -Path $($env:TEMP+"\SystemInfoAutoformat.ps1xml") -Force
}

$computers=@()
$jobs = New-Object System.Collections.ArrayList
$GetWmicompletedForComputers = New-Object System.Collections.ArrayList
$HashtableResult=@{}
$HashtableWMi=@{}
$HashtableRunspace=@()
$Global:ErrorResult=@()
$UpdateFormatData=$true

if ($PSBoundParameters["AppendToResult"].IsPresent)
{
    if (!(Get-Variable -Name Result -Scope Global))
    {
        $Global:Result=@()
    }
    elseif((Get-Variable -Name Result -Scope Global -ValueOnly).count -eq $null)
    {
        $OldRes=$Global:Result
        $Global:Result=@()
        $Global:Result+=$OldRes
    }
}
else
{
    $Global:Result=@()
}

$CountComputers=0
}
process
{
$computers=@()
if ($Name -ne $null)
{
    $computers+=$Name                
}

$computers| foreach {
    $ComputerName=$_
    $CountComputers++
    $TmpObjectProp=@{
    ComputerName=$_
    }
    $TmpObjectWmiProp=@{}
    $AllProperties | foreach {
            if (!$IsAdmin)
            {
                if ($LocalComputer -eq $ComputerName)
                {
                    if ($AdminRequired -eq $_)
                    {

                        Write-Warning "$ComputerName Information may be incomplete. The $_ property requires administrator privileges. Close powershell and run as administrator"
                        
                    }
                }
            }
        
        $TmpObjectProp.add($_,$null)  
    }
    $WmiParamArray | foreach {
        $WmiParam=$_
        $TmpObjectWmiProp.Add($WmiParam["Class"],$null)
    }
    $TmpObject=New-Object psobject -Property $TmpObjectProp
    $TmpObjectWmi=New-Object psobject -Property $TmpObjectWmiProp
    #$TmpObject | Add-Member -NotePropertyName ComputerName -NotePropertyValue $_
    #$TmpObject.ComputerName=$_
    if (!($HashtableResult[$_]))
    {
        [void]$HashtableResult.Add($_,$TmpObject)
    }
    if (!($HashtableWMi[$_]))
    {
        [void]$HashtableWMi.Add($_,$TmpObjectWmi)
    }
    try{
    GetWmi -WmiParamArray $WmiParamArray -ComputerName $_
    }
    catch{
        Write-Error "$_ getwmi error"
    }   
#End Foreach
}


}
end
{
do {
    $repeat=$false
    GetJob
        if ($Jobs.Count -ne 0)
        {
            $repeat=$true
        }
}
while($repeat)

$Global:ErrorResult=$Global:ErrorResult | Sort-Object -Property Warning
if ($Global:ErrorResult -eq $null)
{
    $ErrResCount=0
}
elseif ($Global:ErrorResult.count -eq $null)
{
    $ErrResCount=1
}
else
{
    $ErrResCount=$Global:ErrorResult.count
}

$ResultCount=$Global:Result.count
if ($Global:Result.Count -eq 1)
{
    $Global:Result=$Global:Result | foreach {$_}
}
        
if ($RunspacePool -ne $null)
{
    $RunspacePool.close()
}
if ($ExecutionPolicyChanged)
{
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $CurrentExecutionPolicy -Force -Confirm:$false -ErrorAction SilentlyContinue
}
#Write-Verbose "Clear all failed wmi job"
#Get-Job | Where-Object {$_.State -eq "Failed"} | Remove-Job -Force
if ($PSBoundParameters['ShowStatistics'].ispresent)
{
    Write-Verbose  "Function running  $((New-TimeSpan -Start $BeginFunction).TotalSeconds) seconds" -Verbose
    Write-Verbose  "Total Computers   $CountComputers" -Verbose
    Write-Verbose  "Success           $ResultCount" -Verbose
    Write-Verbose  "Errors            $ErrResCount" -Verbose
}

#End Function
}




}