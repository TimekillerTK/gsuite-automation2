# Logging function
Function LogWrite {
    Param (
        [Parameter(Mandatory=$true)][string]$LogString,
        [string]$Time
        )

    # Checks if the time parameter is present or not
    If ($PSBoundParameters.ContainsKey('Time')) {

        $logfile = "$($MyInvocation.PSScriptRoot)\logs\logfile $([string]($time)).log"

    } else {

        $logfile = "$($MyInvocation.PSScriptRoot)\logfile.log"

    }

    # Set a timestamp
    $checktime = get-date -Format "[dd/MM/yy HH:mm:ss] "
    $logstring = $checktime + $logstring

    # Command outputs both to Verbose pipeline as well as to a file
    Write-Verbose $logstring
    Add-Content $logfile -value $logstring

}