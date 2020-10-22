# Imports public and private functions before running.
BeforeAll {

    . ($PScommandpath.Replace('.tests','')).Replace('\test','')
    $val = ($PSScriptRoot.Replace('\test','')) + "\LogWrite.ps1"
    . $val
    # Need to import module here 
}


<#
$adusers Get-ADObject properties:
- ObjectSID
- mail
- GivenName
- Name
- UserAccountControl

$gsusers Get-GSUser properties:
- ID
- user (mail)
- name.givenname
- name.FamilyName

Todo:
- Checks output when fed AD group and -All
- Checks output when fed AD group and -GSDiff
- Checks output when fed AD group and -ADDiff
- Checks whether the two input objects match

#>

Describe "Get-MatchingUsers Tests" {
    Context "Check Input and Output" {

        It "should return correct value depending on input" {

            Mock "Get-ADObject" { 
                [PSCustomObject]@{
                    ObjectSID = "SID-1-2-3-4"
                    mail = "s_rogers@contoso.com"
                    GivenName = "Steve"
                    Name = "Steve Rogers"
                    UserAccountControl = 512
                }
            }
            Mock "Get-GSUser" {
                [PSCustomObject]@{
                    Id = "109697741504488333908"
                    User = "s_rogers@gsuitedomain.com"
                    Name = [pscustomobject]@{
                        GivenName = "Steve"
                        FamilyName = "Rogers"
                    }
                }
                
            }
            Mock "Get-ADDomainController" { "somedomainconrtroller" }
            Mock "LogWrite" { }
            Mock "FixLastName" { "Rogers" }

            $outputobjectAll = [PScustomobject]@{
                ADSID = "SID-1-2-3-4"
                ADmail = "s_rogers@contoso.com"
                ADFirstName = "Steve"
                ADLastName = "Rogers"
                ADEnabled = 512
                GSID = "109697741504488333908"
                GSmail = "s_rogers@gsuitedomain.com"
                GSFirstName = "Steve"
                GSLastName = "Rogers"
            }

            $properties = $outputobjectAll.PSObject.Properties.Name

            foreach ($name in $properties) {

                (Get-MatchingUsers -GroupDN "SomeGroup" -Scope All).$name | Should -Be $outputobjectAll.$name

            }

        }
    }
}
Describe "FixLastName Tests" {
    Context "ContextName" {
        It "ItName" {
            Assertion
        }
    }
}