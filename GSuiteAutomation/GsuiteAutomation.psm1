$private = @(
    'FixLastName'
    'LogWrite'
    'SendMail'
)

foreach ($file in $private) {
    . ("{0}\private\{1}.ps1" -f $psscriptroot, $file)
}

$public = @(
    'Get-MatchingUsers'

)

foreach ($file in $public) {
    . ("{0}\public\{1}.ps1" -f $psscriptroot, $file)
}

$functionsToExport = @(
    'Get-MatchingUsers'
)

Export-ModuleMember -Function $functionsToExport
