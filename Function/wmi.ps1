function GetNamespace
{
param(
[parameter(Mandatory=$true)]
[string]$Class,
[parameter(Mandatory=$true)]
$ManualNamespace
)
if ($ManualNamespace[$Class])
    {
        $ManualNamespaceParams=ParseParam -ParamString $($ManualNamespace[$Class])
        $ManualNamespaceParamNamespace= $ManualNamespaceParams | Where-Object {$_.namespace}
            if ($ManualNamespaceParams.Namespace)
            {
                $Namespace=$ManualNamespaceParams.Namespace
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
$Namespace
}

function CreateWmiObject
{
param(
[parameter(Mandatory=$true)]
$PropertyParams,
[parameter(Mandatory=$true)]
$ManualNamespace
)
$ObjectWmiArray=@()
$ClassNamespace=@{}
$PropertyParams.Keys | foreach {$Property=$_;$PropertyParams[$_]} | foreach {
    $ArrayClassObject=$null
    $ArrayObject=@()
    $Object=New-Object -TypeName psobject
    $ArrayObject+=$Object
    if($_.Property)
    {
        $Object | Add-Member -MemberType NoteProperty -Name ActionProperty -Value "Property"
        $Object | Add-Member -MemberType NoteProperty -Name Action -Value $_.Property 
    }
    elseif($_.Function)
    {
        
        $Object | Add-Member -MemberType NoteProperty -Name ActionProperty -Value "Function"
        $Object | Add-Member -MemberType NoteProperty -Name Action -Value $_.Function
    }
    
    if ($_.class)
    {
        if ($_.class.gettype() -eq [string])
        {
            $Object | Add-Member -MemberType NoteProperty -Name Class -Value $_.class 
            $Object | Add-Member -MemberType NoteProperty -Name Name -Value $_.class
        }
        elseif($_.class.gettype() -eq [string[]])
        {
            $ArrayClassObject=@()
            $Object | Add-Member -MemberType NoteProperty -Name Class -Value $_.class[0] 
            $Object | Add-Member -MemberType NoteProperty -Name Name -Value $_.class[0]
        $_.class | foreach {
            $ClassObject=New-Object -TypeName psobject
            $ClassObject | Add-Member -MemberType NoteProperty -Name Class -Value $_
            $ClassObject | Add-Member -MemberType NoteProperty -Name Name -Value $_
            $ArrayObject+=$ClassObject
           } 
        
        }
        else
        {
        Write-Error "$($_.class) Unknown type"
        }
        
             
    }
    elseif ($_.query)
    {
        if ($_.query -match ".+from\s(.+?)\s")
        {
            $Name="Query_"+$Matches[1]+"_"+$Property
            $Object | Add-Member -MemberType NoteProperty -Name Class -Value $Matches[1]
            $Object | Add-Member -MemberType NoteProperty -Name Query -Value $_.query
            $Object | Add-Member -MemberType NoteProperty -Name Name -Value $Name
        }
        else
        {
            Write-Error "Query $($_.query) not support"
        }
    }
$Object | Add-Member -MemberType NoteProperty -Name Property -Value $Property   
$ArrayObject | foreach {
    $Class=$_.class
    if ($Class)
    {
        if (!($ClassNamespace[$Class]))
        {
            $Namespace=GetNamespace -Class $Class -ManualNamespace $ManualNamespace
            [void]$ClassNamespace.Add($Class,$Namespace)  
        }  
    $_ | Add-Member -MemberType NoteProperty -Name Namespace -Value $ClassNamespace[$Class] 
    }
}




$ObjectWmiArray+=$ArrayObject
}
$ObjectWmiArray 

}
