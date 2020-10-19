# Imports public and private functions before running.
BeforeAll {

    . ($PScommandpath.Replace('.tests','')).Replace('\test','')

}

Describe "DescribeName" {
    Context "ContextName" {
        It "ItName" {
            Assertion
        }
    }
}