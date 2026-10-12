###################################################################################
# Written by: D. Riley - Malone U.
#     Modified by: J. Beggs - Malone U.
#     --> Created a trimmer and summarizer to make alert message compact
###################################################################################

# get the server name
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$SERVERNAME = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

$xymonHost = "" # ~ ~ ~ ~

# output file
$DATE = date
$HEADER="MegaRaid OK!         $DATE"
#

New-Item -ItemType file -Name statold.txt
New-Item -ItemType file -Name statnew.txt
New-Item -ItemType file -Name raid_report.txt
New-Item -ItemType file -Name raid_report32.txt
New-Item -ItemType file -Name raid_big.txt

# constants
 $column = "raid_info" 
 $color = "green"
 $blankline = "   \n"
$statold = "C:\Scripts\statold.txt"
$statnew = "C:\Scripts\statnew.txt"
$fileName = "C:\Scripts\raid_report.txt"
$fileName32 = "C:\Scripts\raid_report32.txt"
$bigMsg = "C:\Scripts\raid_big.txt"
$sumFile = "C:\scripts\Jsum.txt"
#
 
# get any bad events
C:\"Program Files (x86)\MegaRAID Storage Manager"\storcli.exe "/c0 show events type=sincereboot filter=warning,critical,fatal" > $statnew
# compare old events versus 
if(Compare-Object -ReferenceObject $(Get-Content $statnew) -DifferenceObject $(Get-Content $statold))
 {
    $HEADER="MegaRaid NOT OK!         $DATE"
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
$messageStat = [IO.File]::ReadAllText("c:\scripts\statnew.txt")

# Extract selected fields from each event
$pattern = '(?ms)^Code:\s*(?<Code>.*?)\r?\n' +
           'Class:.*?\r?\n' +
           'Locale:.*?\r?\n' +
           'Event Description:\s*(?<Description>.*?)\r?\n' +
           '.*?Device ID:\s*(?<DeviceID>\d+)\r?\n' +
           'Enclosure Index:\s*(?<Enclosure>\d+)\r?\n' +
           'Slot Number:\s*(?<Slot>\d+)\r?\n' +
           '.*?seqNum:\s*(?<Sequence>\S+)\r?\n' +
           'Time:\s*(?<Time>[^\r\n]+)'

$events = [regex]::Matches($messageStat, $pattern)

# Trim off fluff, leaving only important data
$trimmedReport = foreach ($event in $events) {
    [PSCustomObject]@{
        Code        = $event.Groups['Code'].Value
        Description = $event.Groups['Description'].Value
        DeviceID    = $event.Groups['DeviceID'].Value
        Enclosure   = $event.Groups['Enclosure'].Value
        Slot        = $event.Groups['Slot'].Value
        Sequence    = $event.Groups['Sequence'].Value
        Time        = $event.Groups['Time'].Value
    }
}

$trimmedReport | Format-Table -AutoSize
$trimmedReport > "c:\scripts\RAID_report_trimmed.txt"

# Summarize the trimmed report, giving only a count of events
$summary = $trimmedReport |
    ForEach-Object {
        # Remove the CDB value and everything after it
        $_.Description = $_.Description -replace ', CDB:.*$', ''
        $_
    } |
    Group-Object Description, DeviceID, Enclosure, Slot |
    ForEach-Object {
        [PSCustomObject]@{
            Count       = $_.Count
            Description = $_.Group[0].Description
            DeviceID    = $_.Group[0].DeviceID
            Enclosure   = $_.Group[0].Enclosure
            Slot        = $_.Group[0].Slot
            FirstSeen   = ($_.Group |
                ForEach-Object { $_.Time } |
                Sort-Object -Descending |
                Select-Object -First 1)
            LastSeen    = ($_.Group |
                ForEach-Object { $_.Time } |
                Sort-Object |
                Select-Object -First 1)
        }
    }

$sumText = $summary | Format-Table -AutoSize | Out-String -width 300
$summary > $sumFile

# join header, summary, and storecli.exe results
$BBMSG = (-join "$HEADER","$blankline","Events since last REBOOT:","$blankline","$sumText","$message","$message32")

@"
status $serverName.$column $color

$BBMSG
"@ | Set-Content -Path $bigMsg -Encoding ASCII
& "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost uploadmessage $bigMsg

#cleanup
#erase $bigMsg
erase $fileName
erase $fileName32
erase $statold
erase $statnew
erase $sumFile