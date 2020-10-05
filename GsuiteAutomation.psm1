#Requires -Modules PSGsuite,ActiveDirectory

# Mail sending function
function SendMail {
    [CmdletBinding()]
    param (
        # Smtp server that will send the message
        [Parameter(Mandatory=$true)]
        [string]
        $SmtpServer,

        [Parameter(Mandatory=$true)]
        [string]
        $MailFrom,

        [Parameter(Mandatory=$true)]
        [string]
        $MailTo,

        # Body of the mail, optional.
        [Parameter()]
        [string]
        $MailBody,

        # Sets the E-mail subject line
        [Parameter()]
        [string]
        $Subject = "GSuite script run $(get-date -Format 'dd-MM-yyyy HH:mm:ss')",

        # Sets the E-mail priority
        [Parameter()]
        [string]
        $Priority = "Normal",

        [Parameter()]
        [string]
        $AttachmentPath      
        
    )
  

    $SMTPClient=New-Object System.Net.Mail.smtpClient
    $SMTPClient.host=$smtpServer
    $SMTPClient.EnableSSL=$true
    $SMTPClient.UseDefaultCredentials=$true
    
    
    $MailMessage=New-Object System.Net.Mail.MailMessage
    $MailMessage.Priority= $([System.Net.Mail.MailPriority]::$Priority)
    $MailMessage.From=$MailFrom
    $MailMessage.To.Add($MailTo)
    
    $MailMessage.Subject=$Subject
    $MailMessage.IsBodyHtml=$true
    $MailMessage.BodyEncoding= $([System.Text.Encoding]::UTF8)
    $MailMessage.Body=$MailBody
    $MailMessage.Attachments.Add($AttachmentPath)
    $SMTPClient.Send($MailMessage)
  
}


# Logging function
Function LogWrite {
    Param (
        [string]$LogString,
        [string]$Time
        )

    # Checks if the time parameter is present or not
    If ($PSBoundParameters.ContainsKey('Time')) {
        $logfile = "$($MyInvocation.PSScriptRoot)\logs\logfile $([string]($time)).log"
    } else {
        $logfile = "$($MyInvocation.PSScriptRoot)\logs\logfile.log"
    }

    # Set a timestamp
    $checktime = get-date -Format "[dd/MM/yy HH:mm:ss] "
    $logstring = $checktime + $logstring

    # Command outputs both to Verbose pipeline as well as to a file
    Write-Verbose $logstring
    Add-Content $logfile -value $logstring
}



function Get-MatchingUsers {
    <#
    .SYNOPSIS
    For fetching a list of GSuite and AD Users and matching them up
    
    .DESCRIPTION
    For fetching a list of GSuite and AD Users and matching them up

    
    .EXAMPLE
    Get-MatchingUsers -GroupDN "CN=Group" -Server
    
    .NOTES
    General notes
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$GroupDN,
        [Parameter(ValueFromPipeline=$true)][string]$Server = $(Get-ADDomainController),
        [ValidateSet("All","ADDiff","GSDiff")]
        [string]$Scope = "All"
    )

    PROCESS {
    
        # For logging, setting a variable for LogWrite with a certain date test
        $timevar = Get-Date -Format "dd-MM-yy HH-mm-ss"

<# The querty below is probably the best one, the matching rule OID of 1.2.840.113556.1.4.1941 is a special "extended" match
operator that walks the chain of ancestry in objects all the way to the root, until it finds a match.

Using it in this case, allows for checking members of all nested groups

        # Get-ADObject -LDAPFilter "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))" -Server $Server -Properties mail
        # https://docs.microsoft.com/en-us/windows/win32/adsi/search-filter-syntax?redirectedfrom=MSDN

To check for enabled, disabled and expiring users, check the UserAccountControl attribute:
* 514 = Disabled Account
* 512 = Enabled Account (normal account)
* 16 = locked out
* 
This should be later changed to making an AD account show up as Enabled/Disabled
#>

        # This is broken, returns the default, investigate why
        switch ($PSBoundParameters.Scope) {
            All { LogWrite "All is selected" }
            ADDiff { LogWrite "ADDiff is selected" }
            GSDiff { LogWrite "GSdiff is selected" }
            Default { LogWrite "NONE!!!"}
        }

        # First we need to gather information from both AD and GSuite about current users
        LogWrite "=== Querying AD for group $GroupDN for server $server" -Time $timevar

        $params = @{
            Ldapfilter = "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))"
            Server = $Server
            Properties = "mail","objectsid","department","accountexpires","givenname","UserAccountControl"
        }
        $adusers = Get-ADObject @params

        #$adusers = Get-ADObject -LDAPFilter "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))" -Server $Server -Properties mail,objectsid,department,accountexpires,givenname,UserAccountControl
        LogWrite "=== Querying GSuite for users" -Time $timevar
        $gsusers = Get-GSUser -filter *

        # Checking for ADUsers that are have already been added to GSuite
        LogWrite '=== Looping through $adusers and $gsusers to find common items' -Time $timevar
        $combined = foreach ($aditem in $adusers) {

           
            foreach ($gsitem in $gsusers){

                # Checks if first part of E-mail i_ivanov@ has a match
                if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){

                    # Bandaid to fix some random user inserts, should be fed via parameter later on
                    $lastname = $aditem.Name -replace "$($aditem.GivenName) "
                    $lastname = $lastname -replace "\[Partner\] "
                    $lastname = $lastname -replace "\(Blitz\)"
                    $lastname = $lastname -replace "[0-9]$"

                    LogWrite "Creating PSObject: $($aditem.mail) matched with $($gsitem.user)" -Time $timevar
                    # Creating the Object
                    [PSCustomObject]@{
                        ADSID = $aditem.objectsid
                        ADmail = $aditem.mail
                        ADFirstName = $aditem.GivenName
                        ADLastName = $lastname
                        ADEnabled = $aditem.UserAccountControl
                        GSID = $gsitem.Id
                        GSmail = $gsitem.user
                        GSFirstName = $gsitem.name.GivenName
                        GSLastName = $gsitem.name.FamilyName
                    }
                } 
        
            }
        
        }

        # Checks for AD users which have not been added to GSuite yet
        LogWrite '=== Looping through $adusers and $gsusers to find items only found in $adusers' -Time $timevar
        $different1 = foreach ($aditem in $adusers) {
        
            # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
            if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){

                # Bandaid to fix some random user inserts, should be fed via parameter
                $lastname = $aditem.Name -replace "$($aditem.GivenName) "
                $lastname = $lastname -replace "\[Partner\] "
                $lastname = $lastname -replace "\(Blitz\)"
                $lastname = $lastname -replace "[0-9]$"            
                
                LogWrite "Creating PSObject: $($aditem.mail) with no match" -Time $timevar
                # Creating the Object
                [PSCustomObject]@{
                    ADSID = $aditem.objectsid
                    ADmail = $aditem.mail
                    ADFirstName = $aditem.GivenName
                    ADLastName = $lastname
                    ADEnabled = $aditem.UserAccountControl
                }
            }
        
        }
        
        # Checks for GSuite users that do not have a corresponding AD User account
        LogWrite '=== Looping through $adusers and $gsusers to find items only found in $gsusers' -Time $timevar
        $different2 = foreach ($gsitem in $gsusers) {
        
            # If the mail property of the $gsitem iterated on is NOT in $adusers.mail
            if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){

                LogWrite "Creating PSObject: $($gsitem.user) with no match" -Time $timevar
                # Creating the Object
                [PSCustomObject]@{
                    GSID = $gsitem.Id
                    GSmail = $gsitem.user
                    GSFirstName = $gsitem.name.GivenName
                    GSLastName = $gsitem.name.FamilyName
                }
            }
        
        }

        # Combining everything
        $total = $combined + $different1 + $different2

        # First we need to set the default properties we want in a standard array
        $defaultProperties = 'ADMail', 'GSMail'

        # Now we set up a propertyset
        $defaultPropertiesSet = New-Object System.Management.Automation.PSPropertySet(`
            'DefaultDisplayPropertySet' `
            ,[string[]]$defaultProperties `
            )

        # Create a PS Member Info object from the propertyset
        $members = [System.Management.Automation.PSMemberInfo[]]@($defaultPropertiesSet)

        # Once this is done, we can add this to
        $total | Add-Member MemberSet PSStandardMembers $members
        $total


    } #process
} #function


function New-MatchingUser {
    param (
        
    )
    
}
