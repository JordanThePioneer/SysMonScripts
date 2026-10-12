###################################################################################
# Written by: Driley for Malone U.
# updated for Xymon by D. Riley                    
# Date 6/5/2017                                                  
##################################################################################### 
# get the server name
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$SERVERNAME = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

# Set the xymon server here
$xymonHost = "" # ~ ~ ~ ~

# Set Adjustable Parameters Here
$GB = 1073741824
$MB = 1048576
#pct used threshold
$pctThreshold = 95
#End of adjustable Parameters
######################################################################################
Remove-Item "c:\scripts\ShareReportW.htm"
New-Item -ItemType file -Name ShareReportW.htm
$fileName = "c:\scripts\ShareReportW.htm"

#setup HTML
Function writeHtmlHeader 
{ 
param($fileName) 
#$date = ( Get-Date ).ToString('yyyy/MM/dd') 
$date = Get-Date -format g
Add-Content $fileName "<html>" 
#Add-Content $fileName "<head>" 
#Add-Content $fileName '<h1>File Share Quota Report</h1>' 
#Add-Content $fileName  "<!--" 
#Add-Content $fileName  "td {" 
#Add-Content $fileName  "font-family: Tahoma;" 
#Add-Content $fileName  "font-size: 11px;" 
#Add-Content $fileName  "border-top: 1px solid #999999;" 
#Add-Content $fileName  "border-right: 1px solid #999999;" 
#Add-Content $fileName  "border-bottom: 1px solid #999999;" 
#Add-Content $fileName  "border-left: 1px solid #999999;" 
#Add-Content $fileName  "padding-top: 0px;" 
#Add-Content $fileName  "padding-right: 0px;" 
#Add-Content $fileName  "padding-bottom: 0px;" 
#Add-Content $fileName  "padding-left: 0px;" 
#Add-Content $fileName  "}" 
#Add-Content $fileName  "body {" 
#Add-Content $fileName  "margin-left: 5px;" 
#Add-Content $fileName  "margin-top: 5px;" 
#Add-Content $fileName  "margin-right: 0px;" 
#Add-Content $fileName  "margin-bottom: 10px;" 
#Add-Content $fileName  "" 
#Add-Content $fileName  "table {" 
#Add-Content $fileName  "border: thin solid #000000;" 
#Add-Content $fileName  "}" 
#Add-Content $fileName  "-->" 
#Add-Content $fileName  "</style>" 
#Add-Content $fileName "</head>" 
Add-Content $fileName "<body>" 
Add-Content $fileName  "<table width='100%'>" 
Add-Content $fileName  "<tr bgcolor='#000000'>" 
Add-Content $fileName  "<td colspan='7' height='25' align='center'>" 
Add-Content $fileName  "<font face='tahoma' color='#CEECF5' size='4'><strong>File Share Quota Report - $date</strong></font>" 
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
Add-Content $fileName "<td width='8%' align='center'>Path</td>" 
Add-Content $fileName "<td width='7%' align='center'>Quota(MB)</td>" 
Add-Content $fileName "<td width='6%' align='center'>Used(MB)</td>" 
Add-Content $fileName "<td width='10%' align='center'>Left(MB)</td>" 
Add-Content $fileName "<td width='10%' align='center'>PCT Used</td>"
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
Function get-ShareInfo 
{ 
 $shares = Get-FSRMQuota "W:\Workers\*" |sort $Path
 foreach($share in $shares) 
 { 
    $name = $share.Path 
    $size = ($share.Size / $MB)
    $size = "{0:N1}" -f $size
    $used = ($share.Usage / $MB)
    $used = "{0:N1}" -f $used
    $left = ($size - $used)
    $left = "{0:N1}" -f $left
    $pct = (($used / $size)*100 )
    $pct = "{0:N1}" -f $pct
   writedata $name $size $used $left $pct 

  } 

} 

# Writes the data and conditional warnings for report 
Function WriteData 
{ 
param($name,$size,$used,$left,$pct) 
 
$tableEntry = "<tr><td>$name</td>" 

#Checking the age of the backup 
 
if ($pct -lt $pctThreshold) 
{ 
 $tableEntry += "<td bgcolor='#298A08' align=center>$size</td>" 
 $tableEntry += "<td bgcolor='#298A08' align=center>$used</td>" 
 $tableEntry += "<td bgcolor='#298A08' align=center>$left</td>" 
 $tableEntry += "<td bgcolor='#298A08' align=center>$pct</td>" 
} 
else 
{ 
 $tableEntry += "<td bgcolor='#FF0000' align=center>$size</td>"
 $tableEntry += "<td bgcolor='#FF0000' align=center>$used</td>"
 $tableEntry += "<td bgcolor='#FF0000' align=center>$left</td>"
 $tableEntry += "<td bgcolor='#FF0000' align=center>$pct</td>" 
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
 $message += [IO.File]::ReadAllText("c:\scripts\ShareReportW.htm")
$Mystat = (select-string c:\scripts\ShareReportW.htm -pattern "#FF0000" -Quiet)
echo $Mystat
If  ($Mystat -eq $True )
  {
C:\"Program Files (x86)"\BBWin\bin\bbwincmd.exe $xymonHost status $SERVERNAME fs_W "red+1520m" $message
  }
If  ($Mystat-eq $False )
  {
C:\"Program Files (x86)"\BBWin\bin\bbwincmd.exe $xymonHost status $SERVERNAME fs_W "green+1520m" $message
  }
}


writehtmlheader $fileName 
writetableheader $fileName
get-ShareInfo 
writehtmlfooter $fileName
sendToXymon