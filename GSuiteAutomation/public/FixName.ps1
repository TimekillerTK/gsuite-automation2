function FixName {
    [CmdletBinding()]
    param (

        [Parameter(
            ValueFromPipelineByPropertyName=$true,
            Mandatory=$true
        )]

        [string]$InputString,
        [Parameter(
            Mandatory=$true
        )][string[]]$InputRegex

    )

    # Setting the value to complete the loop
    $setvalue = 0

    # for each supplied regex in $inputregex, check and fix
    foreach ($regex in $InputRegex) {
            
        # if there's a regex match, remove regex from $InputString
        if ($InputString -match $regex) {

            $InputString = $InputString -replace $regex
            $setvalue = 1
            $InputString

        } #if
            
    } #foreach

    # Returns the $InputString in case there were no matches
    if ($setvalue -eq 0) {
        $InputString
    } #if

} #function