###################################################################################
# Written by: D. Riley - Malone U.
# updated for Xymon by D. Riley                    
#
# Script then generates HTML File.
####################################################################################

##################################################################################### 
# Set Adjustable Parameters Here
#backup in days

$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$ServerName = $objIPProperties.HostName
$fullServerName = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

$xymonHost = "" # ~ ~ ~ ~

$backupThreshold = 8
#End of adjustable Parameters (email settings at bottom of script)
######################################################################################
cd c:\scripts
Remove-Item DBReport.htm 
New-Item -ItemType file -Name dbreport.htm
$fileName = "DBReport.htm"

#setup HTML
Function writeHtmlHeader 
{ 
param($fileName) 
$date = ( Get-Date ).ToString('yyyy/MM/dd') 
Add-Content $fileName "<html>" 
Add-Content $fileName "<head>" 
Add-Content $fileName '<h1>SQL Database Backup Report</h1>' 
Add-Content $fileName  "<!--" 
Add-Content $fileName  "td {" 
Add-Content $fileName  "font-family: Tahoma;" 
Add-Content $fileName  "font-size: 11px;" 
Add-Content $fileName  "border-top: 1px solid #999999;" 
Add-Content $fileName  "border-right: 1px solid #999999;" 
Add-Content $fileName  "border-bottom: 1px solid #999999;" 
Add-Content $fileName  "border-left: 1px solid #999999;" 
Add-Content $fileName  "padding-top: 0px;" 
Add-Content $fileName  "padding-right: 0px;" 
Add-Content $fileName  "padding-bottom: 0px;" 
Add-Content $fileName  "padding-left: 0px;" 
Add-Content $fileName  "}" 
Add-Content $fileName  "body {" 
Add-Content $fileName  "margin-left: 5px;" 
Add-Content $fileName  "margin-top: 5px;" 
Add-Content $fileName  "margin-right: 0px;" 
Add-Content $fileName  "margin-bottom: 10px;" 
Add-Content $fileName  "" 
Add-Content $fileName  "table {" 
Add-Content $fileName  "border: thin solid #000000;" 
Add-Content $fileName  "}" 
Add-Content $fileName  "-->" 
Add-Content $fileName  "</style>" 
Add-Content $fileName "</head>" 
Add-Content $fileName "<body>" 
Add-Content $fileName  "<table width='100%'>" 
Add-Content $fileName  "<tr bgcolor='#000000'>" 
Add-Content $fileName  "<td colspan='7' height='25' align='center'>" 
Add-Content $fileName  "<font face='tahoma' color='#CEECF5' size='4'><strong>SQL Database Backup Report - $date</strong></font>" 
Add-Content $fileName  "</td>" 
Add-Content $fileName  "</tr>" 
Add-Content $fileName  "</table>" 
} 
# generates HTML TableHeader  
Function writeTableHeader 
{ 
param($fileName) 
Add-Content $fileName "<table width='100%'><tbody>"  
Add-Content $fileName "<tr bgcolor=#000000>" 
Add-Content $fileName "<td width='8%' align='center'>Database Name</td>" 
Add-Content $fileName "<td width='7%' align='center'>Server</td>" 
Add-Content $fileName "<td width='10%' align='center'>Last Full Backup</td>" 
Add-Content $fileName "<td width='10%' align='center'>Days Since Last Backup</td>"
Add-Content $fileName "</tr>" 
} 
# generates HTML Footer  
Function writeHtmlFooter 
{ 
param($fileName) 
Add-Content $fileName "</table>" 
Add-Content $fileName "</body>" 
Add-Content $fileName "</html>" 
} 
# generate Data 
Function get-DBInfo 
{ 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$SQLServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
    Foreach($db in $SQLServer.Databases) 
 { 
   if ($db.name -eq "VeeamBackup" -or $db.name -eq "master" -or $db.name -eq "msdb" -or $db.name -eq "model" -or $db.name -eq "VeeamOne" )
   {
      $name = $db.name 
      $svr = $ServerName     
        $lastBackup =  $db.LastBackupDate; $currentDate = Get-Date 
      if ($lastBackup -eq $null) 
      {     
       $howOldBkp =  $null      
      } 
      else 
      { 
      $howOldBkp = $currentDate - $lastBackup     
      $howOldBkp = $howOldBkp.days 
 
      } 
      writedata $name $svr  $lastBackup $howOldBkp  
    }
} 
  
} 
# Writes the data and conditional warnings for report 
Function WriteData 
{ 
param($name,$svr,$lastBackup,$howOldBkp) 
 
$tableEntry = "<tr><td>$name</td><td>$svr</td>" 

#Checking the age of the backup 
 
if ($howOldBkp -eq $null) 
{ 
 
 $tableEntry += "<td bgcolor='#FF0000' align=center> null </td>" 
 $tableEntry += "<td bgcolor='#FF0000' align=center>Never Backed Up</td>" 
} 
elseif ($howOldBkp -le $backupThreshold) 
{ 
 $tableEntry += "<td bgcolor='#298A08' align=center>$lastbackup</td>" 
 $tableEntry += "<td bgcolor='#298A08' align=center>$howOldBkp</td>" 
} 
else 
{ 
 $tableEntry += "<td bgcolor='#FF0000' align=center>$lastbackup</td>" 
 $tableEntry += "<td bgcolor='#FF0000' align=center>$howOldBkp</td>"
 } 
Add-Content $fileName $tableEntry 
Write-Host $tableEntry 
} 
# Generate Email 
Function sendEmail 
{ param($from,$to,$subject,$smtphost,$htmlFileName) 
$body = Get-Content $htmlFileName 
$smtp= New-Object System.Net.Mail.SmtpClient $smtphost 
$msg = New-Object System.Net.Mail.MailMessage $from, $to, $subject, $body 
$msg.isBodyhtml = $true 
$smtp.send($msg) 
}
# send to xymon 
Function sendToXymon 
{
 $message += [IO.File]::ReadAllText("c:\scripts\DBReport.htm")
$Mystat = (select-string c:\scripts\DBReport.htm -pattern "#FF0000" -Quiet)
echo $Mystat
If  ($Mystat -eq $True )
  {
C:\"Program Files (x86)"\BBWin\bin\bbwincmd.exe $xymonHost status $fullServerName sqlbk "red+1520m" $message
  }
If  ($Mystat-eq $False )
  {
C:\"Program Files (x86)"\BBWin\bin\bbwincmd.exe $xymonHost status $fullServerName sqlbk "green+1520m" $message
  }
}
#writehtmlheader $fileName 
writetableheader $fileName
get-DBInfo 
writehtmlfooter $fileName
sendToXymon