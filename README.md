# GSuite Automation
Automation tool that makes use of the [PSGsuite](https://psgsuite.io/) module. Logs are automatically generated and saved to `.\logs`. 

`controller.ps1` makes use of the output from `Get-MatchingUsers` function to create new GSUsers

## How to Run
**NOTE:** Early version which works, but is still inefficent and needs some refactoring. 

To run, create the following CSV files in the repo directory `var` location with the following variables:
* `.\var\gsuiteautomation-vars.csv`
  * Server
  * Group 
* `.\var\gsuiteautomation-mailvars.csv`
  * SmtpServer
  * MailFrom
  * MailTo

In addition, in case you want to modify the output of user lastnames by regex match, create a `regex.txt` and add regex strings, one per line. For example, a `regex.txt` with the following contents:
```
[0-9]*
\[USER\]
```

Will remove both numbers and a string of `[USER]` from all user last names output by `Get-MatchingUsers` function.

## Requirements
Was only tested with Powershell

Following modules are required:
* PSGSuite
* ActiveDirectory
* Powershell Version 7.0+

## Todo
* General refactoring
* Script is slow, make it faster
* Logging should be done to a single file, it's currently broken up into a bunch of `*.log` files
* Test with Powershell 5, add support