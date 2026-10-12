###################################################################################
# Written by: D. Riley
# report on Veeam backup jobs
##################################################################################### 
#####Add-PSSnapin VeeamPSSnapin 
######################################################################################
cd C:/Scripts
#Remove-Item JOBReport.htm 
New-Item -ItemType file -Name JOBReport.htm
$fileName = "JOBReport.htm"
New-Item -ItemType file -Name JOBReport.msg
$bigMsg = "JOBReport.msg"

$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$serverName = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

$columnName = "vbkjobs"

$xymonHost = "" # ~ ~ ~ ~
$color = "green"

#setup HTML
Function writeHtmlHeader 
{ 
param($fileName) 
$date = ( Get-Date ).ToString('yyyy/MM/dd') 
Add-Content $fileName "<html>" 
Add-Content $fileName "<head>" 
Add-Content $fileName '<h1>Veeam Backup Report</h1>' 
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
Add-Content $fileName  "<font face='tahoma' color='#CEECF5' size='4'><strong>Veeam Backup Jobs - $date</strong></font>" 
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
Add-Content $fileName "<td width='8%' align='center'>Job Name</td>" 
Add-Content $fileName "<td width='6%' align='center'>Type</td>" 
Add-Content $fileName "<td width='10%' align='center'>Creation Time</td>" 
Add-Content $fileName "<td width='10%' align='center'>Result</td>"
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
Function get-JOBInfo 
{ 
 $jobs = Get-VBRBackupSession | ?{$_.CreationTime -ge (Get-Date).AddDays(-1)} | Select JobName, JobType, CreationTime, Result | Sort CreationTime -Descending
 foreach($job in $jobs) 
 { 
    $name = $job.JobName
    $type = $job.JobType    
    $createtime =  $job.CreationTime
    $lastresult =  $job.Result 
     WriteData $name $type $createtime $lastresult 
} 
  
} 
# Writes the data and conditional warnings for report 
Function WriteData 
{ 
param($name,$type,$createtime,$lastresult) 
 
$tableEntry = "<tr><td>$name</td><td>$type</td><td>$createtime</td>" 

#Checking jobs result 
 

if ($lastresult -eq "Success" -Or $lastresult -eq "None" -Or $lastresult -eq "Warning" ) 
{ 
 $tableEntry += "<td bgcolor='#298A08' align=center>$lastresult</td>" 
} 
else 
{ 
 $tableEntry += "<td bgcolor='#FF0000' align=center>$lastresult</td>" 
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
 $message = [IO.File]::ReadAllText("c:\scripts\JOBReport.htm")
 
 # Create a message file to relay to BBwin
 # Start message file with "status [Server.column] [color]" to replace previous BBwincmd.exe status

$Mystat = (select-string c:\scripts\JOBReport.htm -pattern "#FF0000" -Quiet)
echo $Mystat
If  ($Mystat -eq $True )
  {
  $color = "red"
  @"
status+1h $serverName.$columnName $color

$message
"@ | Set-Content -Path $bigMsg -Encoding ASCII
& "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost uploadmessage $bigMsg
  }
If  ($Mystat-eq $False )
  {
  $color = "green"
  @"
status+1h $serverName.$columnName $color

$message
"@ | Set-Content -Path $bigMsg -Encoding ASCII
& "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost uploadmessage $bigMsg
  }
}
#writehtmlheader $fileName 
writetableheader $fileName
get-JOBInfo 
writehtmlfooter $fileName
sendToXymon

erase $bigMsg
erase $fileName