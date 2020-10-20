# Logging function
Function LogWrite {
    Param (
        [Parameter(Mandatory=$true)][string]$LogString,
        [Parameter(Mandatory=$true)][string]$Path
        )

    $checktime = get-date -Format "[dd/MM/yy HH:mm:ss]-"
    # Using Get-PSCallStack like this may be buggy, investigate later for better ways to do this
    $CallerScript = "[$((Get-PSCallStack).Command[1])] "

    # Set a timestamp
    $logstring = $checktime + $CallerScript + $logstring

    # Command outputs both to Verbose pipeline as well as to a file
    Write-Verbose $logstring
    Add-Content $Path -value $logstring

}