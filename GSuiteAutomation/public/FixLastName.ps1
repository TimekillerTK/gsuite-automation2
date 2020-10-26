# This function accepts an input object then what it does is set the $lastname variable to the users lastname which is taken

function FixLastName {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName=$true)][psobject[]]$InputObject,
        [string[]]$InputRegex,
        [string]$LogPath
    )


    foreach ($object in $InputObject) {

        $setvalue = 0
        LogWrite "=== Object worked on is $($object.name)" -Path $LogPath
        $lastname = $object.name -replace ($object.GivenName + " ")
        LogWrite "=== Lastname with GivenName removed is: $lastname" -Path $LogPath

        foreach ($regex in $InputRegex) {
            
            if ($lastname -match $regex) {
                LogWrite "=== Removing regex $regex" -Path $LogPath
                $lastname = $lastname -replace $regex
                $lastname = $lastname -replace " "
                $setvalue = 1
                $lastname
                LogWrite "Outputting with regex match: $lastname" -Path $LogPath
                
            } 
            
        }

        if ($setvalue -eq 1) {
            LogWrite "=== Setvalue is $setvalue, exiting iteration for $($object.name)" -Path $LogPath
        } else {
            LogWrite "=== Outputting with no match: $lastname" -Path $LogPath
            $lastname
        }
    
    }

}