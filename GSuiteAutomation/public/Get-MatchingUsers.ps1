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
        
        [ValidateSet("All","ADDiff","GSDiff")]
        [string]$Scope = "All",

        [string]$LogPath = "$($MyInvocation.PSScriptRoot)\logfile.log",

        $adusers,

        $gsusers

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

        # Working with $Scope, here's where most of everything will happen, need functions to make it more logical
        switch ($Scope) {
            All { 
                
                LogWrite "Scope: ALL is selected" -Path $LogPath
                LogWrite '=== Looping through $adusers and $gsusers to find common items' -Path $LogPath

                $combined = foreach ($aditem in $adusers) {
                    foreach ($gsitem in $gsusers) {
                        if (($gsitem.user -replace "@(.*)") -eq ($aditem.mail -replace "@(.*)")){

                            #$lastname = #FixLastName @params
                            
                            LogWrite "Creating PSObject: $($aditem.mail) matched with $($gsitem.user)"
                        
                            $params1 = @{
                                ADSID = $aditem.objectsid
                                ADmail = $aditem.mail
                                ADFirstName = $aditem.GivenName
                                ADLastName = $aditem.sn
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

                        #$lastname = #FixLastName @params          
                        
                        LogWrite "Creating PSObject: $($aditem.mail) with no match" -Path $LogPath
                        # Creating the Object
                        $params2 = @{
                            ADSID = $aditem.objectsid
                            ADmail = $aditem.mail
                            ADFirstName = $aditem.GivenName
                            ADLastName = $aditem.sn
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
                        #$lastname = #FixLastName @params          
                        
                        LogWrite "Creating PSObject: $($aditem.mail) with no match" -Path $LogPath
                        # Creating the Object
                        $params2 = @{
                            ADSID = $aditem.objectsid
                            ADmail = $aditem.mail
                            ADFirstName = $aditem.GivenName
                            ADLastName = $aditem.sn
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

