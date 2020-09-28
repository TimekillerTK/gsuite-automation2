#Requires -Modules PSGsuite,ActiveDirectory

# Mail sending function
function SendMail {
  
    # $smtpServer needs to be added
    # $MailBody needs to be added
    # $MailFrom needs to be added
    # $MailTo needs to be added
    # $subj needs to be added 
    
    $SMTPClient=New-Object System.Net.Mail.smtpClient
    $SMTPClient.host=$smtpServer
    $SMTPClient.EnableSSL=$true
    $SMTPClient.UseDefaultCredentials=$true
    
    
    $MailMessage=New-Object System.Net.Mail.MailMessage
    $MailMessage.Priority= $([System.Net.Mail.MailPriority]::High)
    $MailMessage.From=$MailFrom
    $MailMessage.To.Add($MailTo)
    
    $MailMessage.Subject=$subj
    $MailMessage.IsBodyHtml=$true
    $MailMessage.BodyEncoding= $([System.Text.Encoding]::UTF8)
    $MailMessage.Body=$MailBody
    $SMTPClient.Send($MailMessage)
  
  }
  
  # Logging function
  Function LogWrite {
    Param ([string]$logstring)
    # 'dd-MM-yyyy HH.mm.ss' - problem with this is that the log doesn't insert into the correct file because 
    # a new one gets created every second, need to get script execution time or maybe get the variable from Start-Transcript 
    # At the start of the script
    $logfile = ".\logs\pwsh_log_$([string](Get-Date -Format 'dd-MM-yyyy HH.mm.ss')).log"
    Write-Verbose $logstring
    Write-Verbose $myinvocation.mycommand.name
    Add-Content $logfile -value $logstring
  }



function Get-MatchingUsers {
    <#
    .SYNOPSIS
    For fetching a list of GSuite and AD Users and matching them up
    
    .DESCRIPTION
    For fetching a list of GSuite and AD Users and matching them up
    
    .EXAMPLE
    Get-MatchingUsers -GroupDN "CN=Group"
    
    .NOTES
    General notes
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$GroupDN,
        [Parameter(Mandatory=$true)][string]$Server
    )

    PROCESS {
    
    # CAn't get this automatic variable to work for some reason. Try tomorrow.
    # LogWrite "Here's info for myinvocation: $myinvocation"
    # LogWrite "Here's info for PSScriptroot: $($myinvocation.PSScriptRoot)"
    # LogWrite "Here't info for pscommandpath: $($myinvocation.PSCommandPath)"
    #Start-Transcript -Path .\logs\log_$(Get-Date -Format 'dd-MM-yyyy').txt -NoClobber

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
        # LogWrite "=== Querying AD for group $GroupDN for server $server"
        LogWrite "=== Querying AD for group $GroupDN for server $server"

        $params = @{
            Ldapfilter = "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))"
            Server = $Server
            Properties = "mail","objectsid","department","accountexpires","givenname","UserAccountControl"
        }
        $adusers = Get-ADObject @params

        #$adusers = Get-ADObject -LDAPFilter "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))" -Server $Server -Properties mail,objectsid,department,accountexpires,givenname,UserAccountControl
        LogWrite "=== Querying GSuite for users"
        $gsusers = Get-GSUser -filter *

        # Checking for ADUsers that are have already been added to GSuite
        LogWrite '=== Looping through $adusers and $gsusers to find commont items'
        $combined = foreach ($aditem in $adusers) {

           
            foreach ($gsitem in $gsusers){

                # Checks if first part of E-mail i_ivanov@ has a match
                if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){

                    # Bandaid to fix some random user inserts, should be fed via parameter later on
                    $lastname = $aditem.Name -replace "$($aditem.GivenName) "
                    $lastname = $lastname -replace "\[Partner\] "
                    $lastname = $lastname -replace "\(Blitz\)"
                    $lastname = $lastname -replace "[0-9]$"

                    LogWrite "Creating PSObject: $($aditem.mail) matched with $($gsitem.user)"
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
        LogWrite '=== Looping through $adusers and $gsusers to find items only found in $adusers'
        $different1 = foreach ($aditem in $adusers) {
        
            # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
            if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){

                # Bandaid to fix some random user inserts, should be fed via parameter
                $lastname = $aditem.Name -replace "$($aditem.GivenName) "
                $lastname = $lastname -replace "\[Partner\] "
                $lastname = $lastname -replace "\(Blitz\)"
                $lastname = $lastname -replace "[0-9]$"            
                
                LogWrite "Creating PSObject: $($aditem.mail) with no match"
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
        LogWrite '=== Looping through $adusers and $gsusers to find items only found in $gsusers'
        $different2 = foreach ($gsitem in $gsusers) {
        
            # If the mail property of the $gsitem iterated on is NOT in $adusers.mail
            if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){

                LogWrite "Creating PSObject: $($gsitem.user) with no match"
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

function Somethingsomething {
    $val = $myinvocation.mycommand
    $val
}

