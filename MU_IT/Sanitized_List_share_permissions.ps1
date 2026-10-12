###################################################################################
# Written by: D. Riley - Malone U.
#
# 1. List who has share permissions and post it to file Folder_permissions.txt in the high level folder
# 2. get quota stats and email managedby when threashold is exceeded
# 3. post quota stats to file in folder
#
# get the server name
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$SERVERNAME = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

# Set the email details to send from the Help Desk
$emailHost = "" # ~ ~ ~ ~
$emailFrom = "" # ~ ~ ~ ~

# constants
$DATE = date
$CONTACT="Contact for this file share is: "
$HEADER="Shared Folder Report current as of  $DATE"
$HEADER1="Shared Folder Quota Report current as of  $DATE"
$HEADER2="Current Disk Quota Allocation(GBs):"
$HEADER3="Current Disk Usage(GBs):"
$HEADER4="%Used: "
$Blankline = "  "
$messagebody += [IO.File]::ReadAllText("c:\scripts\filesharemsg.txt")
$messagebody1 += [IO.File]::ReadAllText("c:\scripts\filesharemsgUSER1.txt")
$messagebody2 += [IO.File]::ReadAllText("c:\scripts\filesharemsgUSER2.txt")
$fileName = "C:\Scripts\shared_folders.csv"

$GB = 1073741824

# import modules needed
import-module ActiveDirectory

# Get folder list
cd s:\S_drives
Get-Childitem -directory | ft -hidetableheaders name > $filename
Import-csv -Header "Name" $filename | Foreach-Object {
$messagedata = ""
$foldername = $_.Name
$foldername = $foldername.Trim()
#echo "Starting Folder $foldername"

cd S:\S_drives\"$foldername"

# get perms and stats
 $ownerid=(Get-ADGroup "resource drive S $foldername" -Properties ManagedBy).managedby
 $emailTo=(get-aduser $ownerid).UserPrincipalName
$qstats = Get-FSRMQuota S:\S_drives\"$foldername" | Select @{Name="Quota(GB)";E={"{0:N1}" -f ($_.Size/$GB)}},@{Name="Used(GB)";E={"{0:N1}" -f ($_.Usage/$GB)}},@{L='pct used';E={"{0:N1}" -f (($_.usage/$_.size)*100)}}
Get-Adgroupmember "Resource Drive S $foldername" -Recursive | get-aduser |
Select @{Name="LastName";Expression={$_."Surname"}}, @{Name="FirstName";Expression={$_."GivenName"}}, @{Name="UserName";Expression={$_."Name"}} > Folder_permissions.txt
#Get-Adgroupmember "Resource Drive S $foldername" | get-aduser | Select Surname,GivenName,name > AAA_WhoCanAccessThisFolder.txt

$messagedata1 = [IO.File]::ReadAllText("C:\Scripts\filesharemsgUser1.txt")
$messagedata2 = [IO.File]::ReadAllText("S:\S_drives\$foldername\Folder_permissions.txt")
$messagedata3 = [IO.File]::ReadAllText("C:\Scripts\filesharemsgUser2.txt")

$MESSAGE = (-join "$HEADER","$Blankline","$CONTACT",$emailTo,"$Blankline","$HEADER2",$qstats."Quota(GB)","$HEADER3",$qstats."Used(GB)","$HEADER4",$qstats."pct used","$messagebody","$messagedata2") 
echo $MESSAGE > AAA_WhoCanAccessThisFolder.txt
$MESSAGE2 = (-join "$messagedata1","$Blankline","Folder Name: ","$Foldername","$HEADER4",$qstats."pct used","$Blankline","People with access who can clean up the drive: ","$messagedata2","$messagedata3")
echo $MESSAGE2 > AAA_Warning.txt
#
#
# check for warning
if ($qstats."pct used" -gt 92.9)
  {
   $ownerid=(Get-ADGroup "resource drive s $foldername" -Properties ManagedBy).managedby
   $emailTo=(get-aduser $ownerid).UserPrincipalName
   ###$emailTo=(get-aduser driley).UserPrincipalName
### email #
  $smtp = New-Object System.Net.Mail.SmtpClient $emailHost
  $msg = New-Object System.Net.Mail.MailMessage($emailFrom, $emailTo)
  $msg.Subject = "WARNING! Shared S: drive folder " + $foldername + " at " + $qstats."pct used" + " percent of disk space allocation"
  $msg.Body = [IO.File]::ReadAllText("S:\S_drives\$foldername\AAA_Warning.txt") 
  $smtp.send($msg)
  }
erase AAA_Warning.txt
#
}