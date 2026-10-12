###################################################################################
# Written by: D. Riley - Malone U.
# get MegaRaid information
# get the server name
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$SERVERNAME = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

# set the xymon server
$xymonHost = "" # ~ ~ ~ ~

# output file
$DATE = date
$HEADER="<h2>MegaRaid OK!         $DATE</h2>"
#
# constants
 $column = "raid_info" 
 $color = "green"
 $blankline = "   "
$statold = "C:\Scripts\statold.txt"
$statnew = "C:\Scripts\statnew.txt"
$fileName = "C:\Scripts\raid_report.txt"
$fileName2 = "C:\Scripts\raid_report2.txt"
$fileName3 = "C:\Scripts\raid_report3.txt"
$fileName32 = "C:\Scripts\raid_report32.txt"
$bigMsgFile = New-Item -Path "C:\Scripts\" -Name "softwareInv.msg" -ItemType "File"
#
# cleanup
erase $filename
erase $filename2
erase $filename3
erase $filename32
# 
# get any bad events
C:\"Program Files (x86)\MegaRAID Storage Manager"\storcli.exe "/c0 show events type=sincereboot filter=warning,critical,fatal" > $statnew
# compare old events versus 
if(Compare-Object -ReferenceObject $(Get-Content $statnew) -DifferenceObject $(Get-Content $statold))
 {
    $HEADER="<h2>MegaRaid NOT OK!         $DATE</h2>"
    $color="red"
 }
else
 {
    $color="green"
 }
copy $statnew $statold

# get Physical disk info
C:\"Program Files (x86)\MegaRAID Storage Manager"\storcli.exe "/c0 /eall /sall show" > $filename 
# get logical volumes
C:\"Program Files (x86)\MegaRAID Storage Manager"\storcli.exe "/c0 /vall show" > $filename32
#

$message = [IO.File]::ReadAllText("c:\scripts\raid_report.txt")
$message32 = [IO.File]::ReadAllText("c:\scripts\raid_report32.txt")
$Messagestat = [IO.File]::ReadAllText("c:\scripts\statnew.txt")
$BBMSG1 = (-join "$HEADER","$blankline","$Messagestat","$message","$message32")
# Remove unnecessarily long sense data blocks
$BBMSG1 = $BBMSG1 -replace '(?m)^Sense Data:\r?\n^[0-9a-fA-F ]+\r?\n?', ''

# Create a message file to relay to BBwin
# Start message file with "status [Server.column] [color]" to replace previous BBwincmd.exe status
@"
status $SERVERNAME.$column $color

$BBMSG1
"@ | Set-Content -Path $bigMsgFile -Encoding ASCII

# Send message file with status at the beginning and the complete software inventory
& "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost uploadmessage $bigMsgFile

# Send results of inventory to folder for records
$BBMSG2 | Out-File C:\"Program Files (x86)"\BBWin\tmp\sw
$final = $color + "`n" + $BBMSG2
$final | Out-File C:\"Program Files (x86)"\BBWin\tmp\sw

# cleanup
erase $bigMsgFile