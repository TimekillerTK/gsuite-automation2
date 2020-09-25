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
        $adusers = get-aduser -LDAPFilter "(memberof=$GroupDN)" -Server $Server -Properties mail    
        $gsusers = Get-GSUser -filter *

        $combined = foreach ($aditem in $adusers) {

            # Check each item in $gsusers for GSFirstName/GSLastName
            foreach ($gsitem in $gsusers){

        
                if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){
                    [PSCustomObject]@{
                        ADSID = $aditem.sid.value
                        ADmail = $aditem.mail
                        ADFirstName = $aditem.GivenName
                        ADLastName = $aditem.surname
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
                    ADSID = $aditem.sid.value
                    ADmail = $aditem.mail
                    ADFirstName = $aditem.GivenName
                    ADLastName = $aditem.surname
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

        return $combined + $different1 + $different2

    } #process
} #function