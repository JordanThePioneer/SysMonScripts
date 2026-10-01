###################################################################################
# Written by: J. Beggs - Malone U.
# 
#
# Query SQL Database for Right to Cancel Emails that have not been delivered
####################################################################################

Import-Module -Name dbatools

# Logging to check if BBWin has access
$LogFile = "C:\Scripts\SQL_queries.log"

"[$(Get-Date)] RTC Script started as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" |
    Add-Content $LogFile

####################################################################################
# Configuration
# All variables marked with # ~ ~ ~ ~ require input
####################################################################################
# Set the instance
$SqlInstance = "" # ~ ~ ~ ~

# Set the database
$Database = "" # ~ ~ ~ ~ 

# Get the server + Column
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$serverName = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName
$column = "rtc"
$xymonHost = "" # ~ ~ ~ ~
 
# Set the query
$query = @"
select distinct a.Status, d.FROM_EMAIL_ADDRESS, b.RECIPIENT_ADDR, c.SUBJECT,
a.NOTIFICATION_ID, c.MESSAGE_FORMAT, e.AttemptDatetime
from NOTIFICATION_ATTEMPT_HIST a
join NOTIFICATION_RECIPIENT b on a.RECIPIENT_ID = b.RECIPIENT_ID
join NOTIFICATION c on a.NOTIFICATION_ID = c.NOTIFICATION_ID
join FROM_ADDRESS d on c.FROM_ADDRESS_ID = d.FROM_ADDRESS_ID
join NotificationAttemptHistory e on a.NOTIFICATION_ID = e.NotificationInformationID 
where e.STATUS = 'Q'
order by e.AttemptDatetime
"@

####################################################################################


try {
    $results = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $query -EnableException -ErrorAction Stop

    # Logging
    "[$(Get-Date)] RTC Query returned $($results.Count) rows" |
        Add-Content $LogFile

    # If any results are returned, alert and make a BBMsg file with a brief list of the results
    if ($results.Count -gt 0) {
        $BBcolor = "red"

        $table = $results | 
            Select-Object AttemptDatetime, FROM_EMAIL_ADDRESS, RECIPIENT_ADDR, SUBJECT |
            Format-Table -AutoSize |
            Out-String
        $BBMsg = @"
        There are $($results.Count) unsent emails.

        $table
"@
}

    else {
        $BBcolor = "green"
        $BBMsg = "No emails left unsent found."
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