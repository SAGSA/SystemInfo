GetInstalledSoftware -MatchSoftwareName "Skype" -DisplayAdvInfo | Where-Object {$_.publisher -eq "Skype Technologies S.A." -or $_.publisher -match "Microsoft"} | foreach {
    if ($_.appname -match "\d+")
    {
        [version]$SkypeVersion=$_.version
        $_.version=$SkypeVersion
        $_  
    }     
}