function OutResult
{
[CmdletBinding()]
param (
[parameter(ValueFromPipeline=$true)]
$Result

)
process
{
    if($Result)
    {
        
        $Result.PSObject.Properties.Remove('RunspaceId') 
        $Result.PSObject.Properties.Remove('PsComputerName')
        $Result | Get-Member | Where-Object {$_.definition -match "Object" -or $_.definition -match "ModuleSystemInfo"} | foreach {
            $PropertyName=$_.name
            $CompName=$Result.computername
            $Result.$PropertyName | foreach {
                $_ | Add-Member -MemberType NoteProperty -Name PsComputerName -Value $CompName
                $_ | Add-Member -MemberType NoteProperty -Name PSShowComputerName -Value $true
            }
        }    
        if ($UpdateFormatData)
        {
            #Remove old ps1xml file
            $ps1xmlfile=join-path $env:TEMP -ChildPath "SystemInfoAutoformat.ps1xml"
            if (Test-Path $ps1xmlfile)
            {
                Write-Verbose "Remove old ps1xml file $ps1xmlfile"
                try
                {
                    Get-Item -Path $ps1xmlfile -ErrorAction Stop | Remove-Item -Force -ErrorAction Stop
                }
                catch
                {
                    Write-Verbose "Can't delete file $ps1xmlfile"
                }
            }
            CreateFormatPs1xml -ForObject  $Result -ErrorAction Stop
            Update-FormatData -PrependPath $ps1xmlfile -ErrorAction SilentlyContinue
            Set-Variable -Name UpdateFormatData -Value $false -Scope 1 -Force
        }
        $Result.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.AutoFormatObject") 
        $Result
        $Global:Result+=$Result
    }
}

}
function CreateResult
{
#$HashtableWMi[$computername] | Get-Member -MemberType NoteProperty | foreach {New-Variable -Name $_.Name -Value $HashtableWMi[$computername].$($_.Name)[0]}
$HashtableWMi.Keys | foreach {
    Write-Verbose "Create variable $_"
    New-Variable -Name $_ -Value $HashtableWMi[$_]
}
$Result=New-Object -TypeName psobject
$Result | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computername
$WmiParamArray | foreach {
        if ($_.Property)
        {
            $Property=$_.Property
            $Class=$_.class
            $Action=$_.Action
            $ActionProperty=$_.Actionproperty
            if ($ActionProperty -eq "Property")
            {
                Write-Verbose ("$ComputerName Add to result $Property=$"+"$Class.$Action")  
                $WmiVar=$HashtableWMi[$class]
                #$WmiVar | fl
                if ($WmiVar.count -gt 1)
                {  
                    $ResultParamProperty=$WmiVar | foreach {$_.$Action}
                }
                else
                {  
                    $ResultParamProperty=$WmiVar.$Action
                }
    
            }
            elseif ($ActionProperty -eq "Function")
            {
                Write-Verbose ("$ComputerName Add to result $Property=$($_.Action)")
                $ResultParamProperty=&$Action    
                
            }
            if ($ResultParamProperty -eq $null)
            {
                $ResultParamProperty="NotSupported"
            }
            $Result | Add-Member -MemberType NoteProperty -Name $Property -Value $ResultParamProperty
        }
        
    
}
$Result
}