###################################################################################
# Written by: D. Riley - Malone U.
# Modified by: J. Beggs - Malone U. 
#     ~ Bypass command line character limit using BBWin uploadmessage
###################################################################################
      
# Set the Xymon host
$xymonHost = "" # ~.~.~.~

# get the server name
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$SERVERNAME = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

# output file
$DATE = date
$HEADER="Installed Software Listing :         $DATE`n"
$HEADER2=" HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\`n"
$Wow6432=" HKLM:\Software\Wow6432node\Microsoft\Windows\CurrentVersion\Uninstall\ "

# constants
 $column = "sw" 
 $color = "green"
 $blankline = "   "
$fileName = New-Item -Path "C:\Scripts\" -Name "sw_report.txt" -ItemType "File"
$fileName32 = New-Item -Path "C:\Scripts\" -Name "sw_report32.txt" -ItemType "File"
$bigMsgFile = New-Item -Path "C:\Scripts\" -Name "softwareInv.msg" -ItemType "File"

# get the OS version
$computerOS = Get-CimInstance CIM_OperatingSystem
$OS = "Operating System: " + $computerOS.caption + ", Service Pack: " + $computerOS.ServicePackMajorVersion + "`n"

# get 64 bit apps
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where {$_.DisplayName -ne $null} | Select-Object DisplayName, DisplayVersion, InstallDate | Sort-Object DisplayName | Format-Table -AutoSize | Out-File $filename

# get 32 bit apps
Get-ItemProperty HKLM:\Software\Wow6432node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where {$_.DisplayName -ne $null} | Select-Object DisplayName, DisplayVersion, InstallDate | Sort-Object DisplayName | Format-Table -AutoSize | Out-File $filename32


$message = [IO.File]::ReadAllText("c:\scripts\sw_report.txt")
$message32 = [IO.File]::ReadAllText("c:\scripts\sw_report32.txt")
$BBMSG1 = (-join "$HEADER","$OS","$blankline","$HEADER2","$message","$Wow6432","$message32")

# Create a message file to relay to BBwin
@"
status $SERVERNAME.$column $color

$BBMSG1
"@ | Set-Content -Path $bigMsgFile -Encoding ASCII

# Send message file with status at the beginning and the complete software inventory
& "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost uploadmessage $bigMsgFile

# Send results of inventory to folder for records
$BBMSG1 | Out-File C:\"Program Files (x86)"\BBWin\tmp\sw
$final = $color + "`n" + $BBMSG1
$final | Out-File C:\"Program Files (x86)"\BBWin\tmp\sw

# cleanup
erase $fileName
erase $fileName32
erase $bigMsgFile
