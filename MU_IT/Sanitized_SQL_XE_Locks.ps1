###################################################################################
# Written by: J. Beggs - Malone U.
# 
#
# Scan SQL Extended Events log files for deadlock and query blocking events
####################################################################################

Import-Module -Name SqlServer

####################################################################################
# Configuration
####################################################################################

# Get the server + Column
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$serverName = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName
$column = "dl"

$xymonHost = "" # ~ ~ ~ ~
$BBcolor = "green"

$bigMsgFile = New-Item -Path "C:\Scripts\" -Name "deadlock.msg" -ItemType "File"

####################################################################################


try {
     
   $files = Get-ChildItem "C:\SQLTraces\Deadlocks*.xel"

   $sb = [System.Text.StringBuilder]::new()
   $cutoff = (Get-Date).AddHours(-12)
   [void]$sb.AppendLine("<h2>Deadlocks detected since $cutoff :</h2>")
   $dlcount = 0
   $bcount = 0

   foreach ($file in $files) {
        $events = Read-SqlXEvent -FileName $file.FullName
        
        foreach ($event in $events) {
            if ($event.Name -eq "xml_deadlock_report") {
                $xmlString = $event.Fields |
                    Where-Object Key -eq "xml_report" |
                    Select-Object -ExpandProperty Value

                [xml]$deadlockXml = $xmlString

                $victimId = $deadlockXml.deadlock.'victim-list'.victimProcess.id
                $victimProcess = $deadlockXml.deadlock.'process-list'.process |
                    Where-Object { $_.id -eq $victimId }
                $perpProcess = $deadlockXml.deadlock.'process-list'.process |
                    Where-Object { $_.id -ne $victimId } |
                    Select-Object -First 1
                $procQueries = $perpProcess.executionStack.frame |
                    Where-Object { $_.procname -notin @("adhoc", "unknown") }
                $resource = $deadlockXml.deadlock.SelectNodes("//resource-list/*") |
                    Select-Object -First 1
                
                $timestamp = $event.Timestamp.LocalDateTime

                if($timestamp -ge $cutoff) {
                    $dlcount++
                    [void]$sb.AppendLine("<h4>$dlcount :</h4>")
                    [void]$sb.AppendLine("-----Killed process-----")
                    [void]$sb.AppendLine("Timestamp: $timestamp")
                    [void]$sb.AppendLine("Database: $($victimProcess.currentdbname)")
                    [void]$sb.AppendLine("Application: $($victimProcess.clientapp)")
                    [void]$sb.AppendLine("Host Name: $($victimProcess.hostname)")
                    [void]$sb.AppendLine("Transaction Name: $($victimProcess.transactionname)")
                    [void]$sb.AppendLine("Locked Resource: $($resource.objectname)")
                    [void]$sb.AppendLine("Killed SPID: $($victimProcess.spid)")
                    [void]$sb.AppendLine("Killed Query: $($victimProcess.inputbuf)")
                    [void]$sb.AppendLine("")
                    [void]$sb.AppendLine("------Alive process-----")
                    [void]$sb.AppendLine("Alive SPID: $($perpProcess.spid)")
                    [void]$sb.AppendLine("Alive Query: $($perpProcess.inputbuf)")
                }
            }
        }
   }
        
    [void]$sb.AppendLine("<h2>Blocked processes detected since $cutoff :</h2>")

    foreach ($file in $files) {
        $events = Read-SqlXEvent -FileName $file.FullName
        
        foreach ($event in $events) {
            if ($event.Name -eq "blocked_process_report") {
                $xmlString = $event.Fields |
                    Where-Object Key -eq "blocked_process" |
                    Select-Object -ExpandProperty Value

                [xml]$blockXml = $xmlString

                $blockedId = $blockXml.'blocked-process-report'.'blocked-process'.process.id
                $blockedProcess = $blockXml.'blocked-process-report'.'blocked-process'.process |
                    Where-Object { $_.id -eq $blockedId }
                $blockingProcess = $blockXml.'blocked-process-report'.'blocking-process'.process |
                    Where-Object { $_.id -ne $blockedId } |
                    Select-Object -First 1
                $procQueries = $blockingProcess.executionStack.frame |
                    Where-Object { $_.procname -notin @("adhoc", "unknown") }
                $resource = $deadlockXml.deadlock.SelectNodes("//resource-list/*") |
                    Select-Object -First 1
                
                $timestamp = $event.Timestamp.LocalDateTime

                if($timestamp -ge $cutoff) {
                    $bcount++
                    [void]$sb.AppendLine("<h4>$bcount :</h4>")
                    [void]$sb.AppendLine("-----Blocked process-----")
                    [void]$sb.AppendLine("Timestamp: $timestamp")
                    [void]$sb.AppendLine("Database: $($blockedProcess.currentdbname)")
                    [void]$sb.AppendLine("Application: $($blockedProcess.clientapp)")
                    [void]$sb.AppendLine("Host Name: $($blockedProcess.hostname)")
                    [void]$sb.AppendLine("Transaction Name: $($blockedProcess.transactionname)")
                    #[void]$sb.AppendLine("Locked Resource: $($resource.objectname)")
                    [void]$sb.AppendLine("Blocked SPID: $($blockedProcess.spid)")
                    [void]$sb.AppendLine("Blocked Query: $($blockedProcess.inputbuf)")
                    [void]$sb.AppendLine("")
                    [void]$sb.AppendLine("------Blocking process-----")
                    [void]$sb.AppendLine("Blocking SPID: $($blockingProcess.spid)")
                    [void]$sb.AppendLine("Blocking Query: $($blockingProcess.inputbuf)")
                    }
                }
            }
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
    
    if($BBmsg -notlike "*Timestamp*") { 
        $BBcolor = "green" 
        $BBmsg = "No deadlocks found in the last 24 hours"
    }
    else { $BBcolor = "red" }

    @"
status $serverName.$column $BBcolor

$BBmsg
"@ | Set-Content -Path $bigMsgFile -Encoding ASCII

    # Send message file with status at the beginning and the complete software inventory
    & "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost uploadmessage $bigMsgFile

    erase $bigMsgFile
}