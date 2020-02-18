#$Win32_ShadowStorage=Get-WmiObject -Class Win32_ShadowStorage
#$Win32_Volume=Get-WmiObject -Class Win32_Volume
function InvokeExe 
{
[cmdletbinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$ExeFile,
    [Parameter(Mandatory=$false)]
    [String[]]$Args,
    [Parameter(Mandatory=$false)]
    [String]$Verb
)    
    $oPsi = New-Object -TypeName System.Diagnostics.ProcessStartInfo
    $oPsi.CreateNoWindow = $true
    $oPsi.UseShellExecute = $false
    $oPsi.RedirectStandardOutput = $true
    $oPsi.RedirectStandardError = $true
    $oPsi.FileName = $ExeFile
    if (! [String]::IsNullOrEmpty($Args)) 
    {
        $oPsi.Arguments = $Args
    }
    if (! [String]::IsNullOrEmpty($Verb)) 
    {
        $oPsi.Verb = $Verb
    }
    
    $oProcess = New-Object -TypeName System.Diagnostics.Process
    $oProcess.StartInfo = $oPsi

    
    $oStdOutBuilder = New-Object -TypeName System.Text.StringBuilder
    $oStdErrBuilder = New-Object -TypeName System.Text.StringBuilder

    $sScripBlock = {
        if (! [String]::IsNullOrEmpty($EventArgs.Data)) 
        {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    }
    $oStdOutEvent = Register-ObjectEvent -InputObject $oProcess -Action $sScripBlock -EventName 'OutputDataReceived' -MessageData $oStdOutBuilder
    $oStdErrEvent = Register-ObjectEvent -InputObject $oProcess -Action $sScripBlock -EventName 'ErrorDataReceived' -MessageData $oStdErrBuilder

    [Void]$oProcess.Start()
    $oProcess.BeginOutputReadLine()
    $oProcess.BeginErrorReadLine()
    [Void]$oProcess.WaitForExit()

    Unregister-Event -SourceIdentifier $oStdOutEvent.Name
    Unregister-Event -SourceIdentifier $oStdErrEvent.Name
    $oResult = New-Object -TypeName PSObject -Property (@{
        "ExeFile"  = $ExeFile;
        "Args"     = $Args -join " ";
        "ExitCode" = $oProcess.ExitCode;
        "StdOut"   = $oStdOutBuilder.ToString().Trim();
        "StdErr"   = $oStdErrBuilder.ToString().Trim()
    })

return $oResult
}
if ($Win32_ShadowStorage)
{
    if ($Protocol -eq "Wsman")
    {
        $VssAdminPath="$env:SystemRoot\system32\vssadmin.exe"
        $VssAdmin=InvokeExe -ExeFile $VssAdminPath -Args "List ShadowStorage"
        $VssAdminParse=$VssAdmin.StdOut.Split("`n") | Select-String -Pattern volume -Context 1,3
        $count=0
        $VssAdminOuts=@()
        $VssAdminParse | foreach {
            $count++
    
            if ($count%2 -eq 1)
            {
        
                $StringMatches=$VssAdminParse[$count]
                if ($StringMatches.line -match ".+\((\w:)\)")
                {
            
                    $DrLetter=$Matches[1]
                    $n=0
                    $StringMatches.Context.PostContext | foreach {
                        $n++
                        if ($_ -match ".+\:\s(\d.+\s.+)")
                        {
                            if ($n%2 -eq 0)
                            {
                               $AllocatedSpace=$Matches[1]
                            }
                    
                        }
                    }
                    $VssAdminOut=New-Object -TypeName psobject
                    $VssAdminOut | Add-Member -MemberType NoteProperty -Name Driveletter -Value $DrLetter
                    $VssAdminOut | Add-Member -MemberType NoteProperty -Name AllocatedSpace -Value $AllocatedSpace
                    $VssAdminOuts+=$VssAdminOut
        
                }
                else
                {
                    Write-Error "String not match"
                }
        
            }
    
        }

    }
    $Win32_Volume | foreach {
        $Volume=$_
        $VolDeviceID=$($volume.DeviceID -replace "\\","") -replace "\?",""
        $VolumeShadowStor=$Win32_ShadowStorage | Where-Object {$_.volume -match $VolDeviceID}
        if ($VolumeShadowStor)
        {
            $AllocatedSpace=($VssAdminOuts | Where-Object {$_.driveletter -eq $Volume.DriveLetter}).AllocatedSpace
            $Psobj=New-Object -TypeName psobject
            $Psobj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.VolumeShadowStorage")
            $Psobj | Add-Member -MemberType NoteProperty -Name DriveLetter -Value $Volume.DriveLetter
            $Psobj | Add-Member -MemberType NoteProperty -Name UsedSpace -Value $VolumeShadowStor.UsedSpace
            if ($protocol -eq "wsman")
            {
                $Psobj | Add-Member -MemberType NoteProperty -Name AllocatedSpace -Value $AllocatedSpace
            }
            $Psobj | Add-Member -MemberType NoteProperty -Name MaxSpace -Value $VolumeShadowStor.MaxSpace
            $Psobj
        }
    }
}else{
    $Psobj=New-Object -TypeName psobject
    $Psobj.psobject.typenames.insert(0,"ModuleSystemInfo.Systeminfo.Hdd.VolumeShadowStorage")
    $Psobj | Add-Member -MemberType NoteProperty -Name DriveLetter -Value $null
    $Psobj | Add-Member -MemberType NoteProperty -Name UsedSpace -Value 0
    $Psobj | Add-Member -MemberType NoteProperty -Name MaxSpace -Value 0
    $Psobj    
}