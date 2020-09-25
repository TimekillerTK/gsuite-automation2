# Get-ADGroupMember fetches AD group members, however with very limited information, 
# this function will fetch specific properties of AD group members

function Get-ADGroupUserInfo {
    <#
    .SYNOPSIS
    For fetching specific attribute info of AD group members (users)
    
    .DESCRIPTION
    Get-ADGroupMember fetches AD group members, however with very limited information, this function will fetch specific properties of AD group members
    
    .EXAMPLE
    An example
    
    .NOTES
    General notes
    #>
    [CmdletBinding()]
    param (
        [string]$GroupDN,
        [string[]]$Attributes,
        [string]$Server
    )

    PROCESS {

        # $value = Get-ADGroupMember -Identity $Group -Recursive -Server $Server
       # This works great now, but the ADuser search needs to be more refined to take into account nested groups
        #$adusers = get-aduser -LDAPFilter "(memberof=$GroupDN)" -Server $Server -Properties mail    


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

#>
        $adusers = Get-ADObject -LDAPFilter "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))" -Server $Server -Properties mail,objectsid,department,accountexpires,givenname,UserAccountControl
        #$adusers = get-aduser -LDAPFilter "(memberof=$GroupDN)" -Server $Server -Properties mail
        $gsusers = Get-GSUser -filter *


        $combined = foreach ($aditem in $adusers) {

            # Check each item in $gsusers for GSFirstName/GSLastName
            foreach ($gsitem in $gsusers){

        
                if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){
                    [PSCustomObject]@{
                        ADSID = $aditem.objectsid
                        ADmail = $aditem.mail
                        ADFirstName = $aditem.GivenName
                        ADLastName = $aditem.name -replace "$($aditem.givenname) " # This causes an issue with partner account names, investigate how to do it better!
                        GSID = $gsitem.Id
                        GSmail = $gsitem.user
                        GSFirstName = $gsitem.name.GivenName
                        GSLastName = $gsitem.name.FamilyName
                    }
                } 
        
            }
        
        }

    
        $different1 = foreach ($aditem in $adusers) {
        
            # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
            if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){
                [PSCustomObject]@{
                    ADSID = $aditem.objectsid
                    ADmail = $aditem.mail
                    ADFirstName = $aditem.GivenName
                    ADLastName = $aditem.name -replace "$($aditem.givenname) "
                }
            }
        
        }
        
        $different2 = foreach ($gsitem in $gsusers) {
        
            if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){
                [PSCustomObject]@{
                    GSID = $gsitem.Id
                    GSmail = $gsitem.user
                    GSFirstName = $gsitem.name.GivenName
                    GSLastName = $gsitem.name.FamilyName
                }
            }
        
        }

        # Temp, should actually return a 'default' view.
        return $combined + $different1 + $different2



    } #process
} #function