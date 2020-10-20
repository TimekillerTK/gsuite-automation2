$private = @(

)

foreach ($file in $private) {
    . ("{0}\private\{1}.ps1" -f $psscriptroot, $file)
}

$public = @(
    'Get-MatchingUsers'
    'LogWrite'
    'SendMail'
)

foreach ($file in $public) {
    . ("{0}\public\{1}.ps1" -f $psscriptroot, $file)
}

$functionsToExport = @(
    'Get-MatchingUsers'
    'LogWrite'
    'SendMail'
)

Export-ModuleMember -Function $functionsToExport
