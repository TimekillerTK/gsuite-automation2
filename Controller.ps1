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
$import = Import-csv C:\Script\gsuiteautomation-vars.csv

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
If ($newusers -eq $null) {

    LogWrite ">> Controller: No new users needed" -Time $timevar

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
                ErrorAction = 'Stop'
            }
            
            LogWrite ">> Controller: Creating user $($user.admail)" -Time $timevar
            New-GSuser @params

            # setting mailsubject and priority
            $mailsubject = "Success"
            $mailpriority = "Medium"

        } #try
        catch {

            $mailsubject = "Fail"
            $mailpriority = "High"
            
        } #catch
    } #foreach
} #else

LogWrite ">> Controller: Archiving log files..." -Time $timevar
# Compress files here
$archiveparams = @{
    Path = '.\logs\*.log'
    DestinationPath = ".\Logs_$($timevar).zip"
}
Compress-Archive @archiveparams


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
Remove-Item -Path $archiveparams.DestinationPath
Remove-Item -Path $archiveparams.Path