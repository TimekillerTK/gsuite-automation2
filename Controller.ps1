#Requires -Modules GSuiteAutomation
Import-Module GsuiteAutomation -Force
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
$timevar = Get-Date -Format "dd-MM-yy HH-mm-ss"

# Import group from file
$import = Import-csv "C:\Script\gsuiteautomation-vars.csv"

LogWrite ">> Controller: Compiling a list of matching users for AD and GSuite" -Time $timevar
$params = @{
    GroupDN = (Get-ADGroup $import.group).distinguishedname
    Server = $import.server
    Verbose = $true
}

# The below should probably be in a try/catch in case there's an issue pulling from AD or GSuite, or better yet...
# It should be part of the Get-MatchingUsers function!
$dump = Get-MatchingUsers @params
$newusers = $dump | Where-Object {($_.admail -ne $null) -and ($_.gsmail -eq $null)} 

# Checks if no new users need to be added
If ($null -eq $newusers) {

    LogWrite ">> Controller: No new users needed" -Time $timevar
    # SET THE VARS HERE
    $mailsubject = "No new users"
    $mailpriority = "Normal"

} else {
    LogWrite ">> Controller: New GSuite users needed... Creating new users" -Time $timevar
    foreach ($user in $newusers) {

        try {
            
            $params = @{
                # Test the $domain here, not sure if it will work
                PrimaryEmail = $user.admail -replace "@(.*)","$($import.domain)"
                GivenName = $user.adfirstname
                FamilyName = $user.adlastname
                Password = ConvertTo-SecureString -String "$(get-random -Minimum 9999999999999)" -AsPlainText -force
                ErrorAction = 'Stop'
            }
            
            LogWrite ">> Controller: Creating user $($user.admail)" -Time $timevar
            New-GSuser @params

            # setting mailsubject and priority DOES IT FOR EVERY SINGLE USER FIX THIS
            $mailsubject = "Success"
            $mailpriority = "Normal"

        } #try
        catch {
            # DOES IT FOR EVERY SINGLE USER FIX THIS
            LogWrite ">> Controller: Error on $($user.admail)..." -Time $timevar
            $mailsubject = "Fail"
            $mailpriority = "High"

            # This breaks out of the loop, doesn't stop the script though
            break
            
        } #catch
    } #foreach
} #else

LogWrite ">> Controller: Archiving log files..." -Time $timevar
# Compress files here
$archiveparams = @{
    Path = "$PSScriptRoot\logs\*.log"
    DestinationPath = "$PSScriptRoot\Logs_$($timevar).zip"
}
Compress-Archive @archiveparams

# This part needs rethinking, because none of this will be sent and logged,
# Maybe it's a better idea to store the logs somewhere and create a separate file which gets triggered after everything is done to send the logs?
LogWrite ">> Controller: Sending mail about job status: $mailsubject" -Time $timevar
# This var stores the SMTP/MailFrom/MailTo values
$params = Import-csv 'C:\Script\gsuiteautomation-mailvars.csv'
$params | Add-Member -MemberType NoteProperty `
                  -Name 'Priority' `
                  -Value $mailpriority
$params | Add-Member -MemberType NoteProperty `
                  -Name 'Subject' `
                  -Value $mailsubject
$params | Add-Member -MemberType NoteProperty `
                  -Name 'AttachmentPath' `
                  -Value $archiveparams.DestinationPath

# Converting to Hashtable for Splatting, check if there's a better way to do this later.
$hashtable = @{}
foreach( $property in $params.psobject.properties.name )
{
    $hashtable[$property] = $params.$property
}

SendMail @hashtable


LogWrite ">> Controller: Cleaning up files..." -Time $timevar
# Delete items after sending is successful!
# This errors out because the mail process is still using the file at this point which can't be deleted until the message is sent
# Will retry 5 times, then stop 

$archiveparams.DestinationPath, $archiveparams.Path | ForEach-Object {

    do {

        try {

            LogWrite ">> Controller: Attempting to delete files in path $_" -Time $timevar
            Remove-Item -Path $_ -ErrorAction Stop
            $end = 5
        
        } catch {
        
            $end++
            LogWrite ">> Controller: Error deleting file $_, trying again in 5 seconds... " -Time $timevar
            Start-Sleep -s 5
        
        }
        
    } until ($end -eq 5)
        
}
