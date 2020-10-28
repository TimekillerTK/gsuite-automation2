$private = @(

)

foreach ($file in $private) {
    . ("{0}\private\{1}.ps1" -f $psscriptroot, $file)
}

$public = @(
    'Get-MatchingUsers'
    'LogWrite'
    'SendMail'
    'FixName'
)

foreach ($file in $public) {
    . ("{0}\public\{1}.ps1" -f $psscriptroot, $file)
}

$functionsToExport = @(
    'Get-MatchingUsers'
    'LogWrite'
    'SendMail'
    'FixName'
)

Export-ModuleMember -Function $functionsToExport
