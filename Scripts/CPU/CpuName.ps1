$Win32_processor | foreach {
    $_.name -replace "\s+"," "
}