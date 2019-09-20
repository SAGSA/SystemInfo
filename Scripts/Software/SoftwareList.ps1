#To exclude from the output software starting with
$MatchExcludeSoftware = @(
"Security Update for Windows",
"Update for Windows",
"Update for Microsoft",
"Security Update for Microsoft",
"Hotfix",
"Update for Microsoft Office",
" Update for Microsoft Office"
)
GetInstalledSoftware -MatchExcludeSoftware $MatchExcludeSoftware -DisplayAdvInfo

