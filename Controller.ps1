#Requires -Modules GSuiteAutomation
Import-Module GsuiteAutomation -Force

# The following below is unfortunately required for the LogWrite function to work properly
$timevar = Get-Date -Format "dd-MM-yy HH-mm-ss"

# Import important variables needed for script run
$import = Import-csv "$PSScriptRoot\vars\gsuiteautomation-vars.csv"

LogWrite ">> Controller: Started job for checking for new users"
LogWrite ">> Controller: Compiling a list of matching users for AD and GSuite" -Time $timevar
$params = @{
    GroupDN = (Get-ADGroup $import.group).distinguishedname
    Server = $import.server
    Verbose = $true
    Scope = "ADDiff"
}

# The below should probably be in a try/catch in case there's an issue pulling from AD or GSuite, or better yet...
# It should be part of the Get-MatchingUsers function!
$newusers = Get-MatchingUsers @params


# Checks, if no new users need to be added
If ($null -eq $newusers) {

    LogWrite ">> Controller: No new users needed" -Time $timevar

    # SET THE VARS HERE
    $status = "NOACT"
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
            # The below should be logged with LogWrite, at the moment its' being output to terminal
            New-GSuser @params

            # setting status and priority DOES IT FOR EVERY SINGLE USER FIX THIS
            $status = "ADDED"
            $mailpriority = "Normal"

        } #try
        catch {
            # DOES IT FOR EVERY SINGLE USER FIX THIS
            LogWrite ">> Controller: Error on $($user.admail)..." -Time $timevar
            $status = "FAIL"
            $mailpriority = "High"

            # This breaks out of the loop, doesn't stop the script though
            break
            
        } #catch
    } #foreach
} #else

LogWrite ">> Controller: Archiving log files and sending via mail..." -Time $timevar
# Compress files here
$archiveparams = @{
    Path = "$PSScriptRoot\logs\*.log"
    DestinationPath = "$PSScriptRoot\Logs_$($timevar).zip"
}
Compress-Archive @archiveparams

# Mail subject set here, should accept different values
$mailsubject = "[$status] Script run $(get-date -Format 'dd-MM-yyyy HH:mm:ss')"

# This part needs rethinking, because none of this will be sent and logged,
# Maybe it's a better idea to store the logs somewhere and create a separate file which gets triggered after everything is done to send the logs?
LogWrite ">> Controller: Sending mail about job status: $status"
# This var stores the SMTP/MailFrom/MailTo values
$params = Import-csv "$PSScriptRoot\vars\gsuiteautomation-mailvars.csv"
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


LogWrite ">> Controller: Cleaning up files..."

# Delete items after sending is successful!
# This errors out because the mail process is still using the file at this point which can't be deleted until the message is sent
# Will retry 5 times, then stop 
$archiveparams.DestinationPath, $archiveparams.Path | ForEach-Object {

    do {

        # Mail process may not be finished sending mail yet at this point, therefore try/catch
        try {

            LogWrite ">> Controller: Attempting to delete files in path $_"
            Remove-Item -Path $_ -ErrorAction Stop
            $end = 5
        
        } catch {
        
            $end++
            LogWrite ">> Controller: Error deleting file $_, trying again in 5 seconds... "
            Start-Sleep -s 5
        
        }
        
    } until ($end -eq 5)
        
}
