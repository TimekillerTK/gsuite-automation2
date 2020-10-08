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
        $logfile = "$($MyInvocation.PSScriptRoot)\logfile.log"
    }

    # Set a timestamp
    $checktime = get-date -Format "[dd/MM/yy HH:mm:ss] "
    $logstring = $checktime + $logstring

    # Command outputs both to Verbose pipeline as well as to a file
    Write-Verbose $logstring
    Add-Content $logfile -value $logstring
}

# Function for creating the object in Get-MatchingUsers
function OutputObject {
    param (
        $GSID,
        $GSMail,
        $GSFirstName,
        $GSLastName,
        $ADSID,
        $ADmail,
        $ADFirstName,
        $ADLastName,
        $ADEnabled
    )

    $object = [PSCustomObject]@{
        ADSID = $ADSID
        ADmail = $ADmail
        ADFirstName = $ADFirstName
        ADLastName = $ADLastName
        ADEnabled = $ADEnabled
        GSID = $GSID
        GSmail = $GSmail
        GSFirstName = $GSFirstName
        GSLastName = $GSLastName
    }
    return $object

}

function FixLastName {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName=$true)][psobject[]]$InputObject,
        [string[]]$InputRegex
    )


    foreach ($object in $InputObject) {

        $setvalue = 0
        LogWrite "=== Object worked on is $($object.name)" -Time $timevar
        $lastname = $object.name -replace ($object.GivenName + " ")
        LogWrite "=== Lastname with GivenName removed is: $lastname" -Time $timevar

        foreach ($regex in $InputRegex) {
            
            if ($lastname -match $regex) {
                LogWrite "=== Removing regex $regex" -Time $timevar
                $lastname = $lastname -replace $regex
                $lastname = $lastname -replace " "
                $setvalue = 1
                $lastname
                LogWrite "Outputting with regex match: $lastname"
                
            } 
            
        }

        if ($setvalue -eq 1) {
            LogWrite "=== Setvalue is $setvalue, exiting iteration for $($object.name)" -Time $timevar
        } else {
            LogWrite "=== Outputting with no match: $lastname" -Time $timevar
            $lastname
        }
    
    }

}

function Get-MatchingUsers {
    <#
    .SYNOPSIS
    For fetching a list of matching GSuite and AD Users based on AD Group
    
    .DESCRIPTION
    This cmdlet matches up a group of AD Users up against GSuite users based on the mail attribute

    .EXAMPLE
    Get-MatchingUsers -GroupDN "CN=GROUP,OU=Path,DC=corp,DC=contoso,DC=com"
    
    This will return a list of matching users, users unique to AD, and users unique to GS for GROUP

    .EXAMPLE
    Get-MatchingUsers -GroupDN (Get-ADGroup GROUP).DistinguishedName -Server DC-11

    This will return the same as above, but this time querying a specific Domain Controller DC-11 for GROUP

    .EXAMPLE
    Get-MatchingUsers -GroupDN (Get-ADGroup GROUP).DistinguishedName -Scope GSDiff
    
    This will return only users unique to GSuite for GROUP
    
    .NOTES
    General notes
    #>
    [CmdletBinding()]
    param (

        # Supply group in LDAP DistinguishedName format
        [Parameter(Mandatory=$true)]
        [string]$GroupDN,

        [Parameter(ValueFromPipeline=$true)]
        [string]$Server = $(Get-ADDomainController),
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


        # Working with $Scope, here's where most of everything will happen, need functions to make it more logical
        switch ($Scope) {
            All { 
                
                LogWrite "Scope: ALL is selected" -Time $timevar
                LogWrite '=== Looping through $adusers and $gsusers to find common items' -Time $timevar
                $combined = foreach ($aditem in $adusers) {
                    foreach ($gsitem in $gsusers) {
                        if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){

                            $params = @{
                                InputObject = $aditem
                                InputRegex = Get-Content "$($PSScriptRoot)\regexlist.txt"
                            }
                            $lastname = FixLastName @params
                            
                            LogWrite "Creating PSObject: $($aditem.mail) matched with $($gsitem.user)" -Time $timevar
                        
                            $params1 = @{
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
                            OutputObject @params1
                            
                            
                        } #if
                    } #foreach
                } #foreach

                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $adusers' -Time $timevar
                $different1 = foreach ($aditem in $adusers) {
        
                    # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
                    if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){
        
                        $params = @{
                            InputObject = $aditem
                            InputRegex = Get-Content "$($PSScriptRoot)\regexlist.txt"
                        }
                        $lastname = FixLastName @params          
                        
                        LogWrite "Creating PSObject: $($aditem.mail) with no match" -Time $timevar
                        # Creating the Object
                        $params2 = @{
                            ADSID = $aditem.objectsid
                            ADmail = $aditem.mail
                            ADFirstName = $aditem.GivenName
                            ADLastName = $lastname
                            ADEnabled = $aditem.UserAccountControl
                        }
                        OutputObject @params2
                    }
                
                }

                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $gsusers' -Time $timevar
                $different2 = foreach ($gsitem in $gsusers) {
        
                    # If the mail property of the $gsitem iterated on is NOT in $adusers.mail
                    if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){
        
                        LogWrite "Creating PSObject: $($gsitem.user) with no match" -Time $timevar
                        # Creating the Object
                        $params3 = @{
                            GSID = $gsitem.Id
                            GSmail = $gsitem.user
                            GSFirstName = $gsitem.name.GivenName
                            GSLastName = $gsitem.name.FamilyName
                        }
                        OutputObject @params3
                    }
                
                }

                # Combining everything
                $total = $combined + $different1 + $different2
                return $total

                
            } #ALL
            ADDiff { 
                LogWrite "Scope: ADDiff is selected" -Time $timevar
            
                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $adusers' -Time $timevar
                foreach ($aditem in $adusers) {
        
                    # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
                    if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){
        
                        $params = @{
                            InputObject = $aditem
                            InputRegex = Get-Content "$($PSScriptRoot)\regexlist.txt"
                        }
                        $lastname = FixLastName @params          
                        
                        LogWrite "Creating PSObject: $($aditem.mail) with no match" -Time $timevar
                        # Creating the Object
                        $params2 = @{
                            ADSID = $aditem.objectsid
                            ADmail = $aditem.mail
                            ADFirstName = $aditem.GivenName
                            ADLastName = $lastname
                            ADEnabled = $aditem.UserAccountControl
                        }
                        OutputObject @params2
                    }
                
                }

            } #ADDiff
            GSDiff { 

                LogWrite "Scope: GSdiff is selected" -Time $timevar
                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $gsusers' -Time $timevar
                foreach ($gsitem in $gsusers) {
        
                    # If the mail property of the $gsitem iterated on is NOT in $adusers.mail
                    if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){
        
                        LogWrite "Creating PSObject: $($gsitem.user) with no match" -Time $timevar
                        # Creating the Object
                        $params3 = @{
                            GSID = $gsitem.Id
                            GSmail = $gsitem.user
                            GSFirstName = $gsitem.name.GivenName
                            GSLastName = $gsitem.name.FamilyName
                        }
                        OutputObject @params3
                    }
                
                }

            } #GSDiff
            Default { 
                LogWrite "Error Encountered"
                Write-Error "Unknown Error ocurred..."
            } #Default
        } #switch 

    } #process
} #function

