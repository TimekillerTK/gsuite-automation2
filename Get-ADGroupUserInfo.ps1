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
        
        $value | ForEach-Object -parallel {
            # Add user here
        }

    } #process
} #function