#$win32_PowerPlan=Get-WmiObject -Class win32_PowerPlan -Namespace root\cimv2\power
($win32_PowerPlan | Where-Object {$_.isactive -eq $true}).elementname 