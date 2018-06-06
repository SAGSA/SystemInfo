try
{
    $AllLoadedProfile=GetUserProfile -OnlyLoaded -ErrorAction Stop
        $AllNetworkShortcuts=@()
        $AllLoadedProfile | foreach {
            $User=$_.User
            $ProfilePath=$_.LocalPath
            $NetworkShortcutsLocation= Join-Path -Path $ProfilePath -ChildPath "AppData\Roaming\Microsoft\Windows\Network Shortcuts"
            
            if ($Credential)
            {
                $NetworkShortcutsSubFolder=Get-WmiObject -query "ASSOCIATORS OF {Win32_Directory.Name='$NetworkShortcutsLocation'} WHERE AssocClass = Win32_Subdirectory" -Namespace root\cimv2 -ComputerName $Computername -Credential $Credential -ErrorAction Stop
            }
            else
            {
                $NetworkShortcutsSubFolder=Get-WmiObject -query "ASSOCIATORS OF {Win32_Directory.Name='$NetworkShortcutsLocation'} WHERE AssocClass = Win32_Subdirectory" -Namespace root\cimv2 -ComputerName $Computername -ErrorAction Stop
            }
            $AllNetworkShortcutsUser=@()
            if ($NetworkShortcutsSubFolder -ne $null)
            {
                
                $NetworkShortcutsSubFolder | foreach { 
                    $FolderName=$_.FileName
                    $NetworkShortcutsPath=(Join-Path -Path $_.name -ChildPath "target.lnk") -replace "\\","\\" 
                    if ($credential)
                    {
                        $ShortcutFile=Get-WmiObject  -Query "SELECT * FROM Win32_ShortcutFile WHERE Name='$NetworkShortcutsPath'" -Namespace root\cimv2 -ComputerName $Computername -Credential $credential -ErrorAction Stop
                    }
                    else
                    {
                        $ShortcutFile=Get-WmiObject  -Query "SELECT * FROM Win32_ShortcutFile WHERE Name='$NetworkShortcutsPath'" -Namespace root\cimv2 -ComputerName $Computername -ErrorAction Stop
                    }
                    
                    if ($ShortcutFile -ne $null)
                    {
                        
                        $ShortcutFile | foreach {
                            if ($_.target -ne $null)
                            {
                                $TmpObject=New-Object -TypeName psobject | Select-Object -Property User,FolderName,Target
                                $TmpObject.User=$User
                                $TmpObject.FolderName=$FolderName
                                $TmpObject.Target=$_.target
                                $AllNetworkShortcutsUser+=$TmpObject        
                            }
                    
                        }
                    }
                    
                }
                
            }
            else
            {
                $TmpObject=New-Object -TypeName psobject | Select-Object -Property User,FolderName,Target 
                $TmpObject.User=$User
                $TmpObject.FolderName="NoNetResCon"
                $TmpObject.Target=$null
                $AllNetworkShortcuts+=$TmpObject
            }
            

            if ($AllNetworkShortcutsUser.Count -eq 0)
            {
                $TmpObject=New-Object -TypeName psobject | Select-Object -Property User,FolderName,Target 
                $TmpObject.User=$User
                $TmpObject.FolderName=$null
                $TmpObject.Target=$null
                $AllNetworkShortcutsUser+=$TmpObject
            }
        $AllNetworkShortcuts+=$AllNetworkShortcutsUser
        }

    $AllNetworkShortcuts  
    
}
catch
{
 Write-Error $_
}