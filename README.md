# Very fast get system information on a local or remote computer
This module contains PowerShell function Get-SystemInfo that gets  system information via WMI.
## Description
The function uses multithreading. Multithreading is implemented through powershell runspace and PsJob

Function allows you to use protocols DCOM or WSMAN

The function allows you to quickly get the system information of a large number of computers on the network

The function uses WMI to collect information related to the characteristics of the computer

After executing, two variables are created: 

$Result-contains successful queries, 

$ErrorResult-contains computers that have errors.
## Module Installation
### If you use powershell v5 or later
* Run powershell command Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
* Run powershell command Install-Module -Name Systeminfo -Scope CurrentUser
### else
* Run powershell command Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
* Find your PSModule paths by running $env:PSModulePath.Split(";") in a Powershell prompt
* Download the archive SystemInfo_v1.1.0.zip and extract to any one of these paths
* Restart powershell console
* If you have Powershell 3 or higher running the command Get-SystemInfo will automatically import the module, otherwise you'll need to run Import-Module SystemInfo and then run the command.
## Help usage
After installation, you can use the help. Run the command Get-Help Get-SystemInfo
## How to use

### Get system information on the local computer.
``` powershell 
PS C:\>Get-SystemInfo

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
                   Size  InterfaceType Model                           SmartStatus
                   ----  ------------- -----                           --------------
                   112Gb IDE           KINGSTON SHFS37A120G ATA Device OK
                   149Gb IDE           ST3160813AS ATA Device          OK



VideoModel       : Intel(R) HD Graphics 3000
MonitorName      : E2042
CdRom            : TSSTcorp CDDVDW SH-222BB
```
### Get cpu info from remote computers 
``` powershell
 PS C:\>Get-SystemInfo -Computername comp1,comp2 -Cpu

ComputerName   : Comp1
CPUName        : Intel(R) Core(TM) i5-2310 CPU @ 2.90GHz
CPUSocket      : Intel(R) Core(TM) i5-2310 CPU @ 2.90GHz
MaxClockSpeed  : 3201
CPUCores       : 4
CPULogicalCore : 4
CPULoad        : 32

ComputerName   : Comp2
CPUName        : Intel(R) Celeron(R) CPU        E3400  @ 2.60GHz
CPUSocket      : LGA775
MaxClockSpeed  : 2611
CPUCores       : 2
CPULogicalCore : 2
CPULoad        : 42
```
### Get OsCaption, OSArchitecture, OsInstallDate from the computers that are in the 192.168.1.0/24 network and sends them to a grid view window
``` powershell
PS C:\>1..254 | foreach {"192.168.1.$_"} | Get-SystemInfo -Properties OsCaption,OSArchitecture,OsInstallDate -Credential Domain01\administrator01 | Out-GridView
```
### Get Os, CPU, Memory, HDD and Motherboard info
``` powershell
Get-SystemInfo -Osinfo -Cpu -Memory -HDD -Properties Motherboard -Computername comp1,comp2

ComputerName      : Comp1
OsVersion         : 6.1.7601
OSArchitecture    : 32-bit
OsCaption         : Microsoft Windows 7 Профессиональная 
OsInstallDate     : 03.12.2012 11:54:33
OsUpTime          : 0:6:32:38
OsProductKey      : {FFFFF-FFFFF-FFFFF-FFFFF-FFFFF}
OsLoggedInUser    : Domain00\user00
CPUName           : Intel(R) Celeron(R) CPU        E3400  @ 2.60GHz
CPUSocket         : LGA775
MaxClockSpeed     : 2611
CPUCores          : 2
CPULogicalCore    : 2
CPULoad           : 10
MemoryTotal       : 2,0Gb
MemoryFree        : 1,0Gb
MemoryModules     : 
                    Capacity MemoryType Speed Manufacturer  PartNumber
                    -------- ---------- ----- ------------  ----------
                    2Gb      Other      800   Manufacturer0 PartNum0  
                    
                    
                    
MemoryMaxIns      : 8,0Gb
MemorySlots       : 2
MemoryAvailable   : 2,0Gb
MemoryModInsCount : 1
ECCType           : None
HddDevices        : 
                    Size  InterfaceType Model                              PredictFailure
                    ----  ------------- -----                              --------------
                    233Gb IDE           Hitachi HDS721025CLA382 ATA Device False         
                    
                    
                    
HddDevCount       : 1
Motherboard       : ASUSTeK Computer INC.

ComputerName      : Comp2
OsVersion         : 6.1.7601
OSArchitecture    : 64-bit
OsCaption         : Microsoft Windows 7 Корпоративная 
OsInstallDate     : 31.05.2016 14:12:53
OsUpTime          : 14:0:27:53
OsProductKey      : {FFFFF-FFFFF-FFFFF-FFFFF-FFFFF}
OsLoggedInUser    : Domain00\user01
CPUName           : Intel(R) Core(TM) i5-2310 CPU @ 2.90GHz
CPUSocket         : Intel(R) Core(TM) i5-2310 CPU @ 2.90GHz
MaxClockSpeed     : 3201
CPUCores          : 4
CPULogicalCore    : 4
CPULoad           : 12
MemoryTotal       : 6,0Gb
MemoryFree        : 0,8Gb
MemoryModules     : 
                    Capacity MemoryType Speed Manufacturer PartNumber        
                    -------- ---------- ----- ------------ ----------        
                    4Gb      Unknown    1333  0000         GKH400UD51208-1600
                    2Gb      Unknown    1333  0000         [Empty]           
                    
                    
                    
MemoryMaxIns      : 32,0Gb
MemorySlots       : 4
MemoryAvailable   : 5,9Gb
MemoryModInsCount : 2
ECCType           : None
HddDevices        : 
                    Size  InterfaceType Model                            PredictFailure
                    ----  ------------- -----                            --------------
                    112Gb IDE           OCZ-TRION100 ATA Device          False         
                    233Gb IDE           WDC WD2500AAKX-001CA0 ATA Device False         
                    
                    
                    
HddDevCount       : 2
Motherboard       : Gigabyte Technology Co., Ltd.
```
### More Examples
``` powershell
Get-Help Get-SystemInfo -Examples
```
## Properties help
Information | Property | Description |
|-|----------|-------------|
|Os| OsVersion |Get OS Version number |
| | OSArchitecture |Get OS Architecture|
| | OsCaption | Get OS Caption |
| | OsInstallDate |Get OS InstallDate |
| | OsUpTime |Get OS Uptime |
| | OsLoggedInUser | User logged in |
| | OsProductKey | Get OS ProductKey |
| | OsActivationStatus | Get Os ActivationStatus|
| | OsAdministrators | Get Os Administrators |
| Memory | MemoryTotal |Get Memory Total |
| | MemoryFree |Get Memory Free |
| | MemoryModules |Get Memory Modules |
| | MemoryModInsCount |Get Memory modules install count |
| | MemoryMaxIns |Get Memory Maximum Install |
| | MemorySlots |Get Memory Slots |
| | ECCType |Get memory ECCType |
| | MemoryAvailable |Get Memory Available |
| Motherboard | Motherboard |Get Motherboard Manufacturer|
| | MotherboardModel |Get Motherboard Model |
| | DeviceModel |Get Device Model |
| Cdrom | Cdrom |Get Cdrom |
| | CdromMediatype |Get Cdrom Mediatype |
| HDD | HddDevices |Get Hdd devices |
| | HddDevCount |Get Hdd device count |
| | HddPredictFailure |Get HddPredictFailure |
| | HddSmart | Get Hdd Smart |
| Video | VideoModel |Get Video Model |
| | VideoRam |Get Video Ram |
| | VideoProcessor |Get Video Processor |
| CPU | CPUName |Get CPU Name |
| | CPUSocket |Get CPU Socket |
| | MaxClockSpeed | Maximum Clock Speed |
| | CPUCores | CPU Cores |
| | CPULogicalCore |Get CPU LogicalCore |
| | CPULoad |Get CPU Load |
| Monitor | MonitorManuf |Get Monitor Manuf |
| | MonitorPCode |Get Monitor PCode |
| | MonitorSN |Get Monitor SN |
| | MonitorName |Get Monitor Name |
| | MonitorYear |Get Monitor Year |
| Network Adapters | NetPhysAdapCount |Get Network Adapter Count |
| | NetworkAdapters |Get Network Adapters |
| Printers | Printers |Get installed Printers |
| | IsPrintServer | IsPrintServer |
| | UsbConPrOnline |Get usb Connection Printer Online |
| Usb devices | UsbDevices |Get usb Devices |
| Software | SoftwareList | List installed software|

DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK. IF YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, DO NOT USE OUTSIDE OF A SECURE, TEST SETTING.
