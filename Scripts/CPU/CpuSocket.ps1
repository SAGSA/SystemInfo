# 'UpgradeMethod' value from:
# https://schemas.dmtf.org/wbem/cim-html/2.49.0+/CIM_Processor.html
$CPU_UpgradeMethod = DATA {ConvertFrom-StringData -StringData @’
15 = Socket 478
16 = Socket 754
17 = Socket 940
18 = Socket 939
19 = Socket mPGA604
20 = Socket LGA771
21 = Socket LGA775
22 = Socket S1
23 = Socket AM2
24 = Socket F (1207)
25 = Socket LGA1366
26 = Socket G34
27 = Socket AM3
28 = Socket C32
29 = Socket LGA1156
30 = Socket LGA1567
31 = Socket PGA988A
32 = Socket BGA1288
33 = rPGA988B
34 = BGA1023
35 = BGA1224
36 = LGA1155
37 = LGA1356
38 = LGA2011
39 = Socket FS1
40 = Socket FS2
41 = Socket FM1
42 = Socket FM2
43 = Socket LGA2011-3
44 = Socket LGA1356-3
45 = Socket LGA1150
46 = Socket BGA1168
47 = Socket BGA1234
48 = Socket BGA1364
49 = Socket AM4
50 = Socket LGA1151
51 = Socket BGA1356
52 = Socket BGA1440
53 = Socket BGA1515
54 = Socket LGA3647-1
55 = Socket SP3
56 = Socket SP3r2
‘@}
$CpuNameSocket=@{
"Intel(R) Core(TM) i3-2100 CPU @ 3.10GHz"="FCLGA1155"
"Pentium(R) Dual-Core CPU E5400 @ 2.70GHz"="LGA775"
"Intel(R) Pentium(R) CPU G4500 @ 3.50GHz"="FCLGA1151"
"Intel(R) Celeron(R) CPU E3300 @ 2.50GHz"="LGA775"
"Intel(R) Celeron(R) CPU G540 @ 2.50GHz"="FCLGA1155"
"Intel(R) Core(TM) i3-2105 CPU @ 3.10GHz"="FCLGA1155"
"Intel(R) Core(TM) i5-2310 CPU @ 2.90GHz"="LGA1155"
"Intel(R) Pentium(R) CPU G4600 @ 3.60GHz"="FCLGA1151"
"Intel(R) Pentium(R) CPU G620 @ 2.60GHz"="FCLGA1155"
"Pentium(R) Dual-Core CPU E6600 @ 3.06GHz"="LGA775"
"Genuine Intel(R) CPU 2140 @ 1.60GHz"="LGA775,PLGA775"
"Intel(R) Celeron(R) CPU E3400 @ 2.60GHz"="LGA775"
"Intel(R) Pentium(R) CPU G645 @ 2.90GHz"="FCLGA1155"
"Intel(R) Celeron(R) CPU G550 @ 2.60GHz"="FCLGA1155"
"Pentium(R) Dual-Core CPU E5300 @ 2.60GHz"="LGA775"
"Pentium(R) Dual-Core CPU T4400 @ 2.20GHz"="PGA478"
"Intel(R) Xeon(R) CPU E5420 @ 2.50GHz"="LGA771"
}
$Win32_Processor | foreach {
    $CpuName=$($_.name -replace "\s+"," ")
    if ($CpuNameSocket[$CpuName] -eq $null)
    {
        if (($_.SocketDesignation -replace "\s+","") -match "\w+\d{2,}" -and $_.SocketDesignation -ne $_.name )
        {
            $_.SocketDesignation
        }
        else
        {
            if ($CPU_UpgradeMethod["$($_.UpgradeMethod)"] -eq $null)
            {
                "Unknown"
            }
            else
            {
                $CPU_UpgradeMethod["$($_.UpgradeMethod)"]
            }
        }
    }
    else
    {
       $CpuNameSocket[$CpuName] 
    }
    
    
    
}