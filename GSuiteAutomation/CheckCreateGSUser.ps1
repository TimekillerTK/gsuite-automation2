Import-Module "$PSScriptRoot\GSuiteAutomation.psm1" -Force
Import-Module PSGsuite -Force

# The following below is unfortunately required for timestamping log and zip file
$timevar = Get-Date -Format "yyyyMMdd-HHmmss"
$logpath = "$PSScriptRoot\logs\Logfile_$timevar.log"

# Import important variables needed for script run
$import = Import-csv "$PSScriptRoot\vars\gsuiteautomation-vars.csv"
$GroupDN = (Get-ADGroup $import.group).distinguishedname
$Server = $import.server

# Import ADUsers
# First we need to gather information from both AD and GSuite about current users
LogWrite "=== Querying AD for group $GroupDN for server $server" -Path $LogPath -Verbose
$params = @{
    Ldapfilter = "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))"
    Server = $Server
    Properties = "mail","objectsid","department","accountexpires","givenname","UserAccountControl"
}
$adusers = Get-ADObject @params

# Import GSUsers
LogWrite "=== Querying GSuite for users" -Path $LogPath -Verbose
try {

    $gsusers = Get-GSUser -filter *
    
} catch {

    LogWrite "ERROR: Retrieving GSUsers command failed.... Exiting script..." -Path $LogPath
    Write-Error "ERROR: Retrieving GSUsers command failed.... Exiting script... "
    exit

}


LogWrite "Started job for checking for new users" -Verbose -Path $logpath
$params = @{
    Verbose = $true
    Scope = "ADDiff"
    ADUsers = $adusers
    GSUsers = $gsusers
    LogPath = $logpath
}

# The below should probably be in a try/catch in case there's an issue pulling from AD or GSuite, or better yet...
# It should be part of the Get-MatchingUsers function!
$newusers = Get-MatchingUsers @params


# Checks, if no new users need to be added
If ($null -eq $newusers) {

    LogWrite "No new users needed" -Verbose -Path $logpath

    # SET THE VARS HERE
    $status = "NOACT"
    $mailpriority = "Normal"

} else {
    LogWrite "New GSuite users needed... Creating new users" -Verbose -Path $logpath
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
            
            LogWrite "Creating user $($user.admail)" -Verbose -Path $logpath
            # The below should be logged with LogWrite, at the moment its' being output to terminal
            New-GSuser @params | Out-Null

            # setting status and priority DOES IT FOR EVERY SINGLE USER FIX THIS
            $status = "ADDED"
            $mailpriority = "Normal"

        } #try
        catch {
            # DOES IT FOR EVERY SINGLE USER FIX THIS
            LogWrite "Error on $($user.admail)..." -Verbose -Path $logpath
            $status = "FAIL"
            $mailpriority = "High"

            # This breaks out of the loop, doesn't stop the script though
            break
            
        } #catch
    } #foreach
} #else

LogWrite "Archiving log files and sending via mail..." -Verbose -Path $logpath
# Compress files here
$archiveparams = @{
    Path = $logpath
    DestinationPath = "$PSScriptRoot\Logs_$timevar.zip"
}
Compress-Archive @archiveparams

# Mail subject set here, should accept different values
$mailsubject = "[$status] Script run $(get-date -Format 'dd-MM-yyyy HH:mm:ss')"

# This part needs rethinking, because none of this will be sent and logged,
# Maybe it's a better idea to store the logs somewhere and create a separate file which gets triggered after everything is done to send the logs?
LogWrite "Sending mail about job status: $status" -Verbose -Path $logpath
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

# Cleanup will be implemented at a later date.
# LogWrite "Cleaning up archive files..." -Verbose -Path $logpath

# Delete items after sending is successful!
# This errors out because the mail process is still using the file at this point which can't be deleted until the message is sent
# Will retry 5 times, then stop 
# $archiveparams.DestinationPath | ForEach-Object {

#     do {

#         # Mail process may not be finished sending mail yet at this point, therefore try/catch
#         try {

#             LogWrite "Attempting to delete files in path $_" -Verbose -Path $logpath
#             Remove-Item -Path $_ -ErrorAction Stop
#             $end = 5
        
#         } catch {
        
#             $end++
#             LogWrite "Error deleting file $_, trying again in 5 seconds... " -Verbose -Path $logpath
#             Start-Sleep -s 5
        
#         }
        
#     } until ($end -eq 5)
    
# This function checks whether the file in $filepath is currently being used, to be used later
# function CheckFileStatus ($filepath) {
#     $fileInfo = New-Object System.IO.FileInfo $filepath

#     try {

#         $filestream = $fileInfo.Open( [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read )
#         LogWrite ">> CheckFileStatus: File $filepath is not in use. Continuing..." -Verbose -Path
#         return $true

#     } catch {

#         # Too spammy so commented out
#         #LogWrite ">> CheckFileStatus: Warning! File $filepath is in use." -Verbose -Path $logpath
#         return $false

#     }

# }

# This doesn't work for some reason, the file is still opened.
# do {

#     if ((CheckFileStatus -FilePath $archiveparams.DestinationPath) -eq $true) {
        
#         Remove-Item -Path $archiveparams.DestinationPath
#         LogWrite ">> CheckFileStatus: Deleted $($archiveparams.DestinationPath)" -Verbose -Path $logpath
#         $endloop = $true

#     }

# } until ($endloop -eq $true) 

