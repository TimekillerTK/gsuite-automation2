# GSuite Automation
Automation tool that makes use of the [PSGsuite](https://psgsuite.io/) module. Logs are automatically generated and saved to `.\logs`

## How to Run
**NOTE:** Early version which works, but is inefficent and needs some refactoring. 

To run, create the following CSV files in the `C:\Script\` location with the following variables:
* `C:\Script\gsuiteautomation-vars.csv`
  * Server
  * Group 
* `C:\Script\gsuiteautomation-mailvars.csv`
  * SmtpServer
  * MailFrom
  * MailTo

## Requirements
Following modules are required:
* PSGSuite
* ActiveDirectory