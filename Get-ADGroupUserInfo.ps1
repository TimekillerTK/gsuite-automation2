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
        [string]$Group,
        [string[]]$Attributes,
        [string]$Server
    )

    PROCESS {

        $value = Get-ADGroupMember -Identity $Group -Recursive -Server $Server
        
        # Spaghetti code below, which will need to be untangled and incorporated tomorrow:
        #Spaghetti code was fixed at work, but guess what, I forgot to commit the changes
        $list1 = For ($i = 0; $i -lt 15; $i++ ) {
            [pscustomobject]@{
                Email = "$i@something.com"
                HairColor = "blue","yellow","purple" | Get-Random
                EyeColor = "yellow","blue","indigo" | Get-Random
            }
        }
        
        $list2 = For ($i = 0; $i -lt 20; $i++ ) {
            [pscustomobject]@{
                Email = "$i@something.com"
                Height = Get-Random -Minimum 100 -Maximum 220
                Weight = Get-Random -Minimum 40 -Maximum 150
            }
        }
        
        $list1 = Import-Csv -Path .\csv\list1.csv
        $list2 = Import-Csv -Path .\csv\list2.csv
        
        # Check each item in $list1 for Hair/Eye color
        $combined = foreach ($item1 in $list1) {
        
            # Check each item in $list2 for Height/Weight
            foreach ($item2 in $list2){
        
                if ($item2.Email -eq $item1.Email){
                    [PSCustomObject]@{
                        Email = $item1.Email
                        HairColor = $item1.HairColor
                        EyeColor = $item1.EyeColor
                        Height = $item2.Height
                        Weight = $item2.Weight
                    }
                } 
        
            }
        
        
        }
        $different1 = foreach ($item1 in $list1) {
        
            if (!($item1.Email -in $list2.Email)){
                [PSCustomObject]@{
                    Email = $item1.Email
                    HairColor = $item1.HairColor
                    EyeColor = $item1.EyeColor
                }
            }
        
        }
        
        $different2 = foreach ($item2 in $list2) {
        
            if (!($item2.Email -in $list1.Email)){
                [PSCustomObject]@{
                    Email = $item2.Email
                    Height = $item2.Height
                    Weight = $item2.Weight
                }
            }
        
        }
        
        $total = $combined + $different1 + $different2

    } #process
} #function