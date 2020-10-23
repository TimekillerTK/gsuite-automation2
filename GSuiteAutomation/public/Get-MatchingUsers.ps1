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
        
        [string]$Scope = "All",

        [string]$LogPath = "$($MyInvocation.PSScriptRoot)\logfile.log"

    )

    PROCESS {
    
        # Function for creating the object in Get-MatchingUsers
        # Should this be a class?
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
                [string[]]$InputRegex,
                [string]$LogPath
            )
        
        
            foreach ($object in $InputObject) {
        
                $setvalue = 0
                LogWrite "=== Object worked on is $($object.name)" -Path $LogPath
                $lastname = $object.name -replace ($object.GivenName + " ")
                LogWrite "=== Lastname with GivenName removed is: $lastname" -Path $LogPath
        
                foreach ($regex in $InputRegex) {
                    
                    if ($lastname -match $regex) {
                        LogWrite "=== Removing regex $regex" -Path $LogPath
                        $lastname = $lastname -replace $regex
                        $lastname = $lastname -replace " "
                        $setvalue = 1
                        $lastname
                        LogWrite "Outputting with regex match: $lastname" -Path $LogPath
                        
                    } 
                    
                }
        
                if ($setvalue -eq 1) {
                    LogWrite "=== Setvalue is $setvalue, exiting iteration for $($object.name)" -Path $LogPath
                } else {
                    LogWrite "=== Outputting with no match: $lastname" -Path $LogPath
                    $lastname
                }
            
            }
        
        }


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
        LogWrite "=== Querying AD for group $GroupDN for server $server" -Path $LogPath

        $params = @{
            Ldapfilter = "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))"
            Server = $Server
            Properties = "mail","objectsid","department","accountexpires","givenname","UserAccountControl"
        }
        $adusers = Get-ADObject @params

        #$adusers = Get-ADObject -LDAPFilter "(&(memberOf:1.2.840.113556.1.4.1941:=$GroupDN)(ObjectClass=user))" -Server $Server -Properties mail,objectsid,department,accountexpires,givenname,UserAccountControl
        LogWrite "=== Querying GSuite for users" -Path $LogPath
        
        try {

            $gsusers = Get-GSUser -filter *
            
        } catch {

            LogWrite "ERROR: Retrieving GSUsers command failed.... Exiting script..." -Path $LogPath
            Write-Error "ERROR: Retrieving GSUsers command failed.... Exiting script... "
            exit

        }
        
        # Checks whether path with regex strings exists
        $regexpath = Test-Path -Path "$($MyInvocation.PSScriptRoot)\vars\regexlist.txt"

        # Working with $Scope, here's where most of everything will happen, need functions to make it more logical
        switch ($Scope) {
            All { 
                
                LogWrite "Scope: ALL is selected" -Path $LogPath
                LogWrite '=== Looping through $adusers and $gsusers to find common items' -Path $LogPath

                $combined = foreach ($aditem in $adusers) {
                    foreach ($gsitem in $gsusers) {
                        if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){

                            if ($regexpath) {

                                LogWrite "Path exists: $regexpath, will filter lastnames by regex" -Path $LogPath
                                $params = @{
                                    InputObject = $aditem
                                    InputRegex = $regexpath
                                    LogPath = $LogPath
                                }
                            } else {

                                LogWrite "Path does not exist: $regexpath Skipping..." -Path $LogPath
                                $params = @{
                                    InputObject = $aditem
                                    LogPath = $LogPath
                                }
                            }

                            $lastname = FixLastName @params
                            
                            LogWrite "Creating PSObject: $($aditem.mail) matched with $($gsitem.user)"
                        
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

                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $adusers' -Path $LogPath
                $different1 = foreach ($aditem in $adusers) {
        
                    # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
                    if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){
        
                        if ($regexpath) {

                            LogWrite "Path exists: $regexpath, will filter lastnames by regex" -Path $LogPath
                            $params = @{
                                InputObject = $aditem
                                InputRegex = $regexpath
                                LogPath = $LogPath
                            }
                        } else {

                            LogWrite "Path does not exist: $regexpath Skipping..." -Path $LogPath
                            $params = @{
                                InputObject = $aditem
                                LogPath = $LogPath
                            }
                        }

                        $lastname = FixLastName @params          
                        
                        LogWrite "Creating PSObject: $($aditem.mail) with no match" -Path $LogPath
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

                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $gsusers' -Path $LogPath
                $different2 = foreach ($gsitem in $gsusers) {
        
                    # If the mail property of the $gsitem iterated on is NOT in $adusers.mail
                    if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){
        
                        LogWrite "Creating PSObject: $($gsitem.user) with no match" -Path $LogPath
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
                LogWrite "Scope: ADDiff is selected" -Path $LogPath
            
                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $adusers' -Path $LogPath
                foreach ($aditem in $adusers) {
        
                    # If the mail property of the $aditem iterated on is NOT in $gsusers.mail
                    if (!(($aditem.mail -replace "@(.*)") -in ($gsusers.user -replace "@(.*)"))){
        
                        if ($regexpath) {

                            LogWrite "Path exists: $regexpath, will filter lastnames by regex" -Path $LogPath
                            $params = @{
                                InputObject = $aditem
                                InputRegex = $regexpath
                                LogPath = $LogPath
                            }
                        } else {

                            LogWrite "Path does not exist: $regexpath Skipping..." -Path $LogPath
                            $params = @{
                                InputObject = $aditem
                                LogPath = $LogPath
                            }
                        }
                        $lastname = FixLastName @params          
                        
                        LogWrite "Creating PSObject: $($aditem.mail) with no match" -Path $LogPath
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

                LogWrite "Scope: GSdiff is selected" -Path $LogPath
                LogWrite '=== Looping through $adusers and $gsusers to find items only found in $gsusers' -Path $LogPath
                foreach ($gsitem in $gsusers) {
        
                    # If the mail property of the $gsitem iterated on is NOT in $adusers.mail
                    if (!(($gsitem.user -replace "@(.*)") -in ($adusers.mail -replace "@(.*)"))){
        
                        LogWrite "Creating PSObject: $($gsitem.user) with no match" -Path $LogPath
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
                LogWrite "Error Encountered" -Path $LogPath
                Write-Error "Unknown Error ocurred..."
            } #Default
        } #switch 

    } #process
} #function

