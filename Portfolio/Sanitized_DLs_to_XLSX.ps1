###################################################################################
# Written by: J. Beggs - Malone U.
# 
#
# Query SQL Database for any deadlocks that occured in last 20 minutes
# and insert them into an XLSX spreadsheet
####################################################################################

Import-Module -Name SqlServer
Import-Module -Name ImportExcel

####################################################################################
# Configuration
####################################################################################

# Logging to check if BBWin has access
$LogFile = "C:\Scripts\BB_SQL_Test.log"

"[$(Get-Date)] XLSX Script started as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" |
    Add-Content $LogFile

# Clear Excel sheets
erase "C:\SQL_Extended_Event_Reporting\deadlock_report.xlsx"

####################################################################################
    
$ExcelData = @()

$files = Get-ChildItem "C:\SQLTraces\Deadlocks*.xel"

try {
foreach ($file in $files) {
    $events = Read-SqlXEvent -FileName $file.FullName |
        Select-Object -Last 20

    foreach ($event in $events) {
        if ($event.Name -eq "xml_deadlock_report") {

            $timestamp = $event.Timestamp.LocalDateTime

            $xmlString = $event.Fields |
                Where-Object Key -eq "xml_report" |
                Select-Object -ExpandProperty Value

            [xml]$deadlockXml = $xmlString

            $Reports = $deadlockXml.deadlock

            $victimId = $deadlockXml.deadlock.'victim-list'.victimProcess.id

            $victimProcess = $deadlockXml.deadlock.'process-list'.process |
                Where-Object { $_.id -eq $victimId }

            $perpProcess = $deadlockXml.deadlock.'process-list'.process |
                Where-Object { $_.id -ne $victimId } |
                Select-Object -First 1

            $procQueries = $perpProcess.executionStack.frame |
                Where-Object {
                    $_.procname -notin @("adhoc", "unknown")
                }

            $resource = $deadlockXml.deadlock.SelectNodes("//resource-list/*") |
                Select-Object -First 1

            # Build the Excel row
            $ExcelData += [PSCustomObject]@{
                "Timestamp"        = $timestamp
                "Database"         = $victimProcess.currentdbname
                "Application"      = $victimProcess.clientapp
                "Host Name"        = $victimProcess.hostname
                "Transaction Name" = $victimProcess.transactionname
                "Locked Resource" = $resource.objectname
                "Killed SPID"      = $victimProcess.spid
                "Killed Query"     = $victimProcess.inputbuf
                "Alive SPID"       = $perpProcess.spid
                "Alive Query"      = $perpProcess.inputbuf
            }
        }
    }
}

# Export everything at once
$ExcelData | Export-Excel `
    -Path "C:\SQL_Extended_Event_Reporting\deadlock_report.xlsx" `
    -WorksheetName "Deadlocks" `
    -TableStyle Medium2 `
    -AutoSize

$ExcelData = @()

foreach ($file in $files) {
    $events = Read-SqlXEvent -FileName $file.FullName

    foreach ($event in $events) {
        if ($event.Name -eq "blocked_process_report") {

            $timestamp = $event.Timestamp.LocalDateTime

            $xmlString = $event.Fields |
                Where-Object Key -eq "blocked_process" |
                Select-Object -ExpandProperty Value

            [xml]$blockXml = $xmlString

            $Reports = $blockXml.'blocked-process-report'
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

            # Build the Excel row
            $ExcelData += [PSCustomObject]@{
                "Timestamp" = $timestamp
                "Database" = $blockedProcess.currentdbname
                "Application" = $blockedProcess.clientapp
                "Host Name" = $blockedProcess.hostname
                "Transaction Name" = $blockedProcess.transactionname
                #"Locked Resource" = $resource.objectname
                    # Add back in on Solomon
                "Blocked SPID" = $blockedProcess.spid
                "Blocked Query" = $blockedProcess.inputbuf
                    # Switch to $blockedProcess.executionStack.frame.'#text' for Solomon
                "Blocking SPID" = $blockingProcess.spid
                "Blocking Query" = $blockingProcess.inputbuf
                    # Switch to $procQueries.'#text' for Solomon
            }
        }
    }
}

# Export everything at once
$ExcelData | Export-Excel `
    -Path "C:\SQL_Extended_Event_Reporting\deadlock_report.xlsx" `
    -WorksheetName "Blocks" `
    -TableStyle Medium2 `
    -AutoSize

} # end try

catch {
    $errorMsg = "[$(Get-Date)] ERROR: $($_.Exception.Message)" 
    $errorMsg | Add-Content $LogFile
    $BBMsg = $errorMsg
    $BBcolor = "red"
    throw
}
