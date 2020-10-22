Import-Module "$PSScriptRoot\GSuiteAutomation.psm1" -Force

# # The following below is unfortunately required for timestamping log and zip file
$timevar = Get-Date -Format "yyyyMMdd-HHmmss"
$logpath = "$PSScriptRoot\logs\Logfile_$timevar.log"

# Import important variables needed for script run
$import = Import-csv "$PSScriptRoot\vars\gsuiteautomation-vars.csv"

LogWrite "Started job for checking for users to be deleted" -Verbose -Path $logpath
$params = @{
    GroupDN = (Get-ADGroup $import.group).distinguishedname
    Server = $import.server
    Verbose = $true
    Scope = "GSDiff"
    LogPath = $logpath
}

# Get the list of users
$delusers = Get-MatchingUsers @params

# Apply exceptions to the list of deleted users to remove, for example, service accounts
if (Test-Path -Path "$PSScriptRoot\vars\gsuiteautomation-exceptions.txt") {
    LogWrite "Exceptions file found.." -Verbose -Path $logpath

    $temp = Get-Content "$PSScriptRoot\vars\gsuiteautomation-exceptions.txt"
    foreach ($item in $temp) {
        
        LogWrite "Removing exception $item from `$delusers" -Verbose -Path $logpath
        # If there are a lot of exceptions this will be a VERY slow operation, find a better way to do it later
        $delusers = $delusers | Where-Object {$_.GSMail -ne $item}

    }
    $delusers | Format-Table
} else {
    
    LogWrite "No exceptions file found, printing output" -Verbose -Path $logpath
    $delusers | Format-Table
}

