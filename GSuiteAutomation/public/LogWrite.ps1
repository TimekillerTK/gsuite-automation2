# Logging function
Function LogWrite {
    Param (
        [Parameter(Mandatory=$true)][string]$LogString,
        [Parameter(Mandatory=$true)][string]$Path
        )

    ## $PATH SHOULD PROBABLY BE OPTIONAL AND JUST OUTPUT VERBOSE OUTPUT

    $CheckTime = get-date -Format "[dd/MM/yy HH:mm:ss]"
    # Using Get-PSCallStack like this may be buggy, investigate later for better ways to do this
    $CallerScript = "[$((Get-PSCallStack).Command[1])]"

    # Set a timestamp
    $LogString = "{0}-{1} {2}" -f $CheckTime,$CallerScript,$LogString

    # Command outputs both to Verbose pipeline as well as to a file
    Write-Verbose $LogString
    Add-Content $Path -value $LogString

}