# GSuite Automation
Automation tool that makes use of the [PSGsuite](https://psgsuite.io/) module. Logs are automatically generated and saved to `.\logs`. 
* `CheckCreateGSUser.ps1` takes output from the `Get-MatchingUsers` function to automagically create new GSUsers.
* `CheckUserstoDelete.ps1` filters out the GSUsers who do not have a corresponding AD Account which can probably be deleted. **Does not delete users**, just outputs a list.

## How to Use
---
**NOTE:** Early version which works, but is still inefficent and needs some more refactoring. 

---
### Requirements:
Following modules are required:
* [PSGSuite](https://psgsuite.io/) (make sure you configure it for your domain first)
* [ActiveDirectory](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/features-on-demand-non-language-fod#remote-server-administration-tools-rsat)
* [Powershell 7.0+](https://github.com/PowerShell/PowerShell/releases/tag/v7.0.3)

To run either script, it is **mandatory** to create the following files in the `var` directory with the following variables:
* `.\var\gsuiteautomation-vars.csv` (used by `CheckCreateGSUser.ps1` and `CheckUserstoDelete.ps1`)
  * Server
  * Group 
* `.\var\gsuiteautomation-mailvars.csv` (used by `CheckCreateGSUser.ps1`)
  * SmtpServer
  * MailFrom
  * MailTo

Optionally, add the following optional files for more variables:
* `.\var\regexlist.txt` 
  * Used by `CheckCreateGSUser.ps1`. In case you have any prefixes such as `[USER]` or numbers in AD names, you can have those removed using regex strings put in this file, one per line:
    ```
    [0-9]*
    \[USER\]
    ```

* `.\var\gsuiteautomation-exceptions.txt`
  * Used by `CheckUserstoDelete.ps1`,


In addition, in case you want to modify the output of user lastnames by regex match, create a `regex.txt` and add regex strings, one per line. For example, a `regex.txt` with the following contents:

Will remove both numbers and a string of `[USER]` from all user last names output by `Get-MatchingUsers` function.



## Todo
* General refactoring
* Script is slow, make it faster
* ~~Logging should be done to a single file, it's currently broken up into a bunch of `*.log` files~~
  * Fixed
* After running scripts, you'll be left with logfiles and zip files. At least one should be cleaned up after a run.
* Test with Powershell 5, add support