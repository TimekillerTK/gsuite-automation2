# Imports public and private functions before running.
BeforeAll {

    . ($PScommandpath.Replace('.tests','')).Replace('\test','')

}

<#
We want to test the following things:
- When inputting a string and path, the file is created in the correct location with the correct string
- When inputting a string and not a path, the file is created in the default location
- Should check, if the line is getting correctly timestamped

#>


Describe "LogWrite Tests" {
    Context "Output tests" {

        # Mock "Get-Date" {
        #     "[dd/MM/yy HH:mm:ss]"
        # }


        It "should be in correct location with correct string with path" {

            $TestFilePath = 'TestDrive:\TestLog.log'
            LogWrite -Path $TestFilePath -LogString "Spaghetti Check!"
            
            Get-Content -Path $TestFilePath | Should -BeLike "*Spaghetti Check!"

        }
        It "should be in correct location with correct string without path" -Skip {
            
        }

        It "should check if the line is correctly timestamped" {

            $date = Get-Date -Format "[dd/MM/yy HH:mm:ss]"
            $TestFilePath = 'TestDrive:\TestLog.log'
            LogWrite -Path $TestFilePath -LogString "Spaghetti Check!"

            $Temp = Get-Content -Path $TestFilePath
            $Array = $Temp.Split('-')

            $Array[0] | Should -Be $date

        }
    }
}


