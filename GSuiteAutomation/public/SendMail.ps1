
function SendMail {
    [CmdletBinding()]
    param (
        # Smtp server that will send the message
        [Parameter(Mandatory=$true)]
        [string]
        $SmtpServer,

        [Parameter(Mandatory=$true)]
        [string]
        $MailFrom,

        [Parameter(Mandatory=$true)]
        [string]
        $MailTo,

        # Body of the mail, optional.
        [Parameter()]
        [string]
        $MailBody,

        # Sets the E-mail subject line
        [Parameter()]
        [string]
        $Subject = "GSuite script run $(get-date -Format 'dd-MM-yyyy HH:mm:ss')",

        # Sets the E-mail priority
        [Parameter()]
        [string]
        $Priority = "Normal",

        [Parameter()]
        [string]
        $AttachmentPath      
        
    )
  

    $SMTPClient=New-Object System.Net.Mail.smtpClient
    $SMTPClient.host=$smtpServer
    $SMTPClient.EnableSSL=$true
    $SMTPClient.UseDefaultCredentials=$true
    
    
    $MailMessage=New-Object System.Net.Mail.MailMessage
    $MailMessage.Priority= $([System.Net.Mail.MailPriority]::$Priority)
    $MailMessage.From=$MailFrom
    $MailMessage.To.Add($MailTo)
    
    $MailMessage.Subject=$Subject
    $MailMessage.IsBodyHtml=$true
    $MailMessage.BodyEncoding= $([System.Text.Encoding]::UTF8)
    $MailMessage.Body=$MailBody
    $MailMessage.Attachments.Add($AttachmentPath)
    $SMTPClient.Send($MailMessage)
  
}