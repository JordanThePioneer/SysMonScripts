###################################################################################
# Written by: J. Beggs - Malone U.
# 
#
# Query SQL Database for Right to Cancel Emails that have not been delivered
####################################################################################

Import-Module -Name dbatools

# Logging to check if BBWin has access
$LogFile = "C:\Scripts\SQL_queries.log"

"[$(Get-Date)] Inv Script started as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" |
    Add-Content $LogFile

####################################################################################
# Configuration
#
# All variables marked with # ~ ~ ~ ~ require input
####################################################################################

# Set the instance
$SqlInstance = "" # ~ ~ ~ ~

# Set the database
$Database = "" # ~ ~ ~ ~ 

# Get the server + Column
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$serverName = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName
$column = "inv"
$xymonHost = "" # ~ ~ ~ ~

# Set the query
$query = @"
select ch.APPID, ch.CHECK_NUM_NUMERIC, ch.CHECK_NAME, ch.ID_NUM
 from CHK_RECONCILIATION ch
 left outer join TRANS_HIST t on ch.CHECK_NUM_NUMERIC = t.CHECK_NUM_NUM
 where t.APPID is null
 and CHECK_VOID_FLAG is null
 and year(ch.JOB_TIME) >= 2025
 order by ch.JOB_TIME
"@

####################################################################################


try {
    $results = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $query -EnableException -ErrorAction Stop

    # Logging
    "[$(Get-Date)] Inv Query returned $($results.Count) rows" |
        Add-Content $LogFile

    # If any results are returned, alert and make a BBMsg file with a brief list of the results
    if ($results.Count -gt 0) {
        $BBcolor = "red"

        $table = $results | 
            Select-Object AttemptDatetime, FROM_EMAIL_ADDRESS, RECIPIENT_ADDR, SUBJECT |
            Format-Table -AutoSize |
            Out-String
        $BBMsg = @"
        There are $($results.Count) checks not connected to invoices.

        $table
"@
}

    else {
        $BBcolor = "green"
        $BBMsg = "No checks found disconnected from an invoice."
    }
}
 
catch {
    $errorMsg = "[$(Get-Date)] ERROR: $($_.Exception.Message)" 
    $errorMsg | Add-Content $LogFile
    $BBMsg = $errorMsg
    $BBcolor = "red"
    throw
}

finally {
    #Write-Host ($BBMsg)
    & "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost status $serverName $column $BBcolor $BBMsg 13h
}
