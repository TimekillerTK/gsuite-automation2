#Requires -Modules GSuiteAutomation

# Controller script for the process
<#
1. Use Get-MatchingUsers function to get a dump of info and store it in a variable $dump
2. For each $user of $dump that have $_.admail and don't have $_.gsmail, create GSUser in Try/Catch function
    - If fails, set subject to "FAILED", set high priority
    - If succeeds, set normal mail subject, set medium priority
3. Zip logs
4. Send mail with attached zipped log
#>

<#
VARS THAT NEED TO BE INPUT:
$server (DC)
$group (DistinguishedName)
$domain (mail domain for GSuite Server)
#>

# The following below is unfortunately required for the LogWrite function to work properly
$timevar = Get-Date -Format "MM-dd-yy HH-mm-ss"

LogWrite ">> Controller: Compiling a list of matching users for AD and GSuite" -Time $timevar
$params = @{
    GroupDN = (Get-ADGroup $group).distinguishedname
    Server = $server
    Verbose = $true
}

# The below should probably be in a try/catch in case there's an issue pulling from AD or GSuite, or better yet...
# It should be part of the Get-MatchingUsers function!
$dump = Get-MatchingUsers @params
$newusers = $dump | Where-Object {($_.admail -ne $null) -and ($_.gsmail -eq $null)} 

# Checks if the $newusers is null
If ($newusers -eq $null) {
    LogWrite ">> Controller: No new users needed" -Time $timevar
    #Send empty mail informing the script ran but didn't create any new users
} else {
    LogWrite ">> Controller: New GSuite users needed... Creating new users" -Time $timevar
    foreach ($user in $newusers) {

        try {
            
            $params = @{
                # Test the $domain here, not sure if it will work
                PrimaryEmail = $user.admail -replace "@(.*)","$domain"
                GivenName = $user.adfirstname
                FamilyName = $user.adlastname
                Password = ConvertTo-SecureString -String "$(get-random -Minimum 9999999999999)" -AsPlainText -force
                ErrorAction = Stop
            }
            
            LogWrite ">> Controller: Creating user $($user.admail)" -Time $timevar
            New-GSuser @params

            # setting mailsubject and priority
            $mailsubject = "Success"
            $mailpriority = "Medium"

        } #try
        catch {

            $mailsubject = "Failed"
            $mailpriority = "High"
            
        } #catch
    } #foreach
} #else
