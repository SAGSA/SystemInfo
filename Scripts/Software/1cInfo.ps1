GetInstalledSoftware -MatchSoftwareName "1[C,С]" -DisplayAdvInfo | Where-Object {$_.publisher -match "$1[C,С]"} | foreach {
    if ($_.appname -match "\d+")
    {
        [version]$SAppVersion=$_.version
        $_.version=$SAppVersion
        $_  
    }     
}