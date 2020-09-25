#Requires -Modules PSGsuite,ActiveDirectory

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
        [string]$GroupDN,
        #[string[]]$Attributes,
        [string]$Server
    )

    PROCESS {

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
        $adusers = Get-ADObject -LDAPFilter "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))" -Server $Server -Properties mail,objectsid,department,accountexpires,givenname,UserAccountControl
        $gsusers = Get-GSUser -filter *

        # Checking for ADUsers that are have already been added to GSuite
        $combined = foreach ($aditem in $adusers) {

           
            foreach ($gsitem in $gsusers){

                # Checks if first part of E-mail i_ivanov@ has a match
                if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){

                    # Bandaid to fix some random user inserts, should be fed via parameter later on
                    $lastname = $aditem.Name -replace "$($aditem.GivenName) "
                    $lastname = $lastname -replace "\[Partner\] "
                    $lastname = $lastname -replace "\(Blitz\)"
                    $lastname = $lastname -replace "[0-9]$"

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
        $different1 = foreach ($aditem in $adusers) {
        
            # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
            if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){

                # Bandaid to fix some random user inserts, should be fed via parameter
                $lastname = $aditem.Name -replace "$($aditem.GivenName) "
                $lastname = $lastname -replace "\[Partner\] "
                $lastname = $lastname -replace "\(Blitz\)"
                $lastname = $lastname -replace "[0-9]$"            
                
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
        $different2 = foreach ($gsitem in $gsusers) {
        
            # If the mail property of the $gsitem iterated on is NOT in $adusers.mail
            if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){
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