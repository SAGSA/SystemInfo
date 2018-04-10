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
    elseif($ForObject.RunspaceId)
    {
    }
    elseif($PropertyParams[$Property].FormatList)
    {
        $XmlFormatList+="
        <ListItem>
        <Label>$Property</Label>
            <ScriptBlock> 
                $DollarUnder.$Property | Format-List | Out-String
            </ScriptBlock>
        </ListItem>"
    }
    elseif ($FormatTableFor -eq ($ForObjectProperty).GetType().name)
    {
        $XmlFormatList+="
        <ListItem>
        <Label>$Property</Label>
            <ScriptBlock> 
                $DollarUnder.$Property | Format-Table -autosize | Out-String
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