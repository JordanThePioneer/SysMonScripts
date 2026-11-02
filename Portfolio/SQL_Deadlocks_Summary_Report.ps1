###################################################################################
# Written by: J. Beggs - Malone U.
# 
#
# Search Extended Events XML files, find deadlock reports, and summarize findings
#     within the last 12 hours
####################################################################################

Import-Module -Name SqlServer

####################################################################################
# Configuration
####################################################################################

# Get the server + Column
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$serverName = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName
$column = "dl"
$XymonHost = "" # ~.~.~.~
$BBcolor = "green"

$bigMsgFile = New-Item -Path "C:\Scripts\" -Name "deadlock.msg" -ItemType "File"

####################################################################################


try {
     
   $files = Get-ChildItem "C:\SQLTraces\Deadlocks*.xel"

   $cutoff = (Get-Date).AddHours(-12)

   # ##########################################
   # Extracting Deadlock events from the XML
   # ##########################################

   $deadlockEvents = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $files) {

    $events = Read-SqlXEvent -FileName $file.FullName

    foreach ($event in $events) {

        if ($event.Name -ne "xml_deadlock_report") {
            continue
        }

        $timestamp = $event.Timestamp.LocalDateTime

        if ($timestamp -lt $cutoff) {
            continue
        }

        $xmlString = $event.Fields |
            Where-Object Key -eq "xml_report" |
            Select-Object -ExpandProperty Value

        [xml]$deadlockXml = $xmlString

        $deadlock = $deadlockXml.SelectSingleNode("//deadlock")

        if ($null -eq $deadlock) {
            continue
        }

        # Identify victim processes
        $victimIds = @(
            $deadlock.SelectNodes("./victim-list/victimProcess") |
                ForEach-Object { $_.GetAttribute("id") }
        )

        # Extract all participating processes
        $processes = foreach ($process in $deadlock.SelectNodes(
            "./process-list/process"
        )) {

            $inputbuf = $process.SelectSingleNode("./inputbuf")

            # Stored procedures from execution stack
            $procedures = @(
                $process.SelectNodes("./executionStack/frame") |
                    ForEach-Object {
                        $procName = $_.GetAttribute("procname")

                        if ($procName -and $procName -notin @(
                            "adhoc", "unknown"
                        )) {
                            $procName
                        }
                    }
            )

            [PSCustomObject]@{
                ID              = $process.GetAttribute("id")
                IsVictim        = $process.GetAttribute("id") -in $victimIds
                SPID            = $process.GetAttribute("spid")
                DatabaseID      = $process.GetAttribute("currentdb")
                Application     = $process.GetAttribute("clientapp")
                HostName        = $process.GetAttribute("hostname")
                TransactionName = $process.GetAttribute("transactionname")
                Query           = if ($inputbuf) {
                    $inputbuf.InnerText.Trim()
                } else {
                    ""
                }
                Procedures      = $procedures
            }
        }

        # Extract all locked objects rather than just the first one
        $resources = foreach ($resource in $deadlock.SelectNodes(
            "./resource-list/*"
        )) {

            [PSCustomObject]@{
                Type      = $resource.LocalName
                Object    = $resource.GetAttribute("objectname")
                Index     = $resource.GetAttribute("indexname")
                DatabaseID = $resource.GetAttribute("dbid")
            }
        }

        $deadlockEvents.Add(
            [PSCustomObject]@{
                Timestamp  = $timestamp
                Processes  = @($processes)
                Resources  = @($resources)
                Victim     = @($processes | Where-Object IsVictim)
                Survivors  = @($processes | Where-Object {
                    -not $_.IsVictim
                })
            }
        )
    }
}

    # ########################################
    # Grouping Deadlock events by signature
    # ########################################

    $groupedDeadlocks = $deadlockEvents | Group-Object -Property {

    $event = $_

    $objects = @(
        $event.Resources |
            Where-Object Object |
            ForEach-Object Object |
            Sort-Object -Unique
    ) -join ","

    $procedures = @(
        $event.Processes |
            ForEach-Object Procedures |
            Sort-Object -Unique
    ) -join ","

    $database = @(
        $event.Processes |
            ForEach-Object DatabaseID |
            Sort-Object -Unique
    ) -join ","

    $application = @(
        $event.Processes |
            ForEach-Object Application |
            Sort-Object -Unique
    ) -join ","

    "$database|$application|$objects|$procedures"

} | Sort-Object Count -Descending
    

    # #####################################
    # Generate sb String and pass to Xymon
    # #####################################

    $sb = [System.Text.StringBuilder]::new()

    $totalDeadlocks = $deadlockEvents.Count
    $patternCount = $groupedDeadlocks.Count

    [void]$sb.AppendLine("<h2>SQL Deadlock Summary - Last 12 Hours</h2>")
    [void]$sb.AppendLine("Total Deadlocks: $totalDeadlocks")
    [void]$sb.AppendLine("Unique Patterns: $patternCount")
    [void]$sb.AppendLine("")

    $patternNumber = 0

    foreach ($group in $groupedDeadlocks) {

        $patternNumber++

        $percentage = [math]::Round(
            ($group.Count / $totalDeadlocks) * 100, 1
        )

        $groupEvents = $group.Group

        $firstEvent = $groupEvents |
            Sort-Object Timestamp |
            Select-Object -First 1
            
        $lastEvent = $groupEvents |
            Sort-Object Timestamp -Descending |
            Select-Object -First 1

        # Use the most recent event as the sample
        $sample = $lastEvent

        $victim = $sample.Victim | Select-Object -First 1
        $survivor = $sample.Survivors | Select-Object -First 1

        $objects = @(
            $sample.Resources |
                Where-Object Object |
                ForEach-Object Object |
                Sort-Object -Unique
        )

        [void]$sb.AppendLine("<h3>Pattern $patternNumber</h3>")
        [void]$sb.AppendLine("Occurrences: $($group.Count)      $($percentage) % of total deadlocks")
        [void]$sb.AppendLine("First Seen: $($firstEvent.Timestamp)")
        [void]$sb.AppendLine("Last Seen: $($lastEvent.Timestamp)")

        [void]$sb.AppendLine("Locked Objects:")
        foreach ($object in $objects) {
            [void]$sb.AppendLine(" - $object")
        }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Application: $($victim.Application)")
        [void]$sb.AppendLine("Victim SPID: $($victim.SPID)")
        [void]$sb.AppendLine("Survivor SPID: $($survivor.SPID)")

        [void]$sb.AppendLine("Victim Query:")
        [void]$sb.AppendLine("<div style='white-space:pre-wrap; overflow-wrap:anywhere;'>")
        [void]$sb.AppendLine($victim.Query)
        [void]$sb.AppendLine("</div>")

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Survivor Query:")
        [void]$sb.AppendLine("<div style='white-space:pre-wrap; overflow-wrap:anywhere;'>")
        [void]$sb.AppendLine($survivor.Query)
        [void]$sb.AppendLine("</div>")

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("--------------------------------")
    }

    $BBmsg = $sb.ToString()

}   

catch {
    $errorMsg = "[$(Get-Date)] ERROR: $($_.Exception.Message)" 
    $errorMsg | Add-Content $LogFile
    $BBMsg = $errorMsg
    $BBcolor = "red"
    throw
}

finally {
    
    if($totalDeadlocks -eq 0) { 
        $BBcolor = "green" 
        $BBmsg = "No deadlocks found in the last 24 hours"
    }
    else { $BBcolor = "red" }

    @"
status $serverName.$column $BBcolor

$BBmsg
"@ | Set-Content -Path $bigMsgFile -Encoding ASCII

    # Send message file with status at the beginning and the complete software inventory
    & "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $XymonHost uploadmessage $bigMsgFile

    erase $bigMsgFile
}
