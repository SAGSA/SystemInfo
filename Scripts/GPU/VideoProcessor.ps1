$Win32_VideoController | foreach {
    if ($_.name -notmatch "Radmin.+" -and $_.name -notmatch "DameWare.+")
	{																
	    $_.VideoProcessor															
	} 
}