function FixLastName {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName=$true)][psobject[]]$InputObject,
        [string[]]$InputRegex
    )


    foreach ($object in $InputObject) {

        $setvalue = 0
        LogWrite "=== Object worked on is $($object.name)" -Time $timevar
        $lastname = $object.name -replace ($object.GivenName + " ")
        LogWrite "=== Lastname with GivenName removed is: $lastname" -Time $timevar

        foreach ($regex in $InputRegex) {
            
            if ($lastname -match $regex) {
                LogWrite "=== Removing regex $regex" -Time $timevar
                $lastname = $lastname -replace $regex
                $lastname = $lastname -replace " "
                $setvalue = 1
                $lastname
                LogWrite "Outputting with regex match: $lastname"
                
            } 
            
        }

        if ($setvalue -eq 1) {
            LogWrite "=== Setvalue is $setvalue, exiting iteration for $($object.name)" -Time $timevar
        } else {
            LogWrite "=== Outputting with no match: $lastname" -Time $timevar
            $lastname
        }
    
    }

}