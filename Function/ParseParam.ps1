function ParseFunctionConfig
{
[cmdletbinding()]
param(
[parameter(ValueFromPipeline=$true)]
$Property,
[Hashtable]$FunctionConfig,
$Protocol
)
begin
{
    if ($Protocol -eq "Wsman")
    {
    [Array]$PassParams="Class","Query","Script"
    }
    else
    {
    [Array]$PassParams="Class","Query"
    }
    $PropertyParams=@{}
    
}
process
{
    
    if (!($FunctionConfig[$Property]))
        {
            Write-Error "Property $Property not found in $('$FunctionConfig')" -ErrorAction Stop
        }
    $ObjectParam=ParseParam -ParamString $FunctionConfig[$Property] -Property $Property -ErrorAction Stop
    if ($ObjectParam | Get-Member -MemberType NoteProperty | foreach {if ($PassParams -eq $_.name){$True}})
    {
    if (!($PropertyParams.ContainsKey($Property)))
        {
        $PropertyParams.Add($Property,$ObjectParam)
        }
    
    }
    else
    {
        Write-Error "$Property missing parameter.At least one parameter is required from $PassParams. Check FunctionConfig" -ErrorAction Stop
    }
}
end
{
$PropertyParams
}

}

Function ParseParam
{
[cmdletbinding()]
param(
[parameter(Mandatory=$true)]
[string]$ParamString,
[String]$Property
)

$PermitParams="Class","ScriptBlock","UseRunspace","RunspaceImportVariable","Property","Query","Namespace","Script","FormatList"
[array]$SwitchParam="FormatList"
$ArrayHashTableParam=@()
$ArrayParamString=(((($ParamString -replace "\s+"," ") -replace "\s+$","") -replace "^-"," -") -replace " -"," --") -split "\s-"
$HashTableParam=@{}
$ArrayParamString | foreach {
    
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
        
        
    
    }
    elseif ($_ -match "-(.+\S)")
    {
        if ($SwitchParam -eq $Matches[1])
        {
            $HashTableParam.Add($Matches[1],$True)
        }
        else
        {
            $HashTableParam.Add($Matches[1],$null)  
        }     
    }
# End Foreach
}
$ObjectParam=New-Object -TypeName psobject -Property $HashTableParam
$DifObj=$ObjectParam | Get-Member -MemberType NoteProperty | foreach {$_.name}
$CompareParam=Compare-Object -ReferenceObject $PermitParams -DifferenceObject $DifObj
if ($CompareParam | where-object {$_.sideindicator -eq "=>"})
{
    Write-Error "$Property Parameter -$(($CompareParam | Where-Object {$_.SideIndicator -eq "=>"}).inputobject) not allowed. Check FunctionConfig" -ErrorAction Stop
}
$ObjectParam

#End Function
}
