###################################################################################
# Written by: J. Beggs - Malone U.
# 
#
# Query SQL Database for any students that appear in query
####################################################################################

Import-Module -Name dbatools

# Logging to check if BBWin has access
$LogFile = "C:\Scripts\SQL_queries.log"

"[$(Get-Date)] JICS SQL Script started as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" |
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
$column = "jics"
$xymonHost = "" # ~ ~ ~ ~
 
# Set the query
$query = @"
select *
from tmseprd.dbo.tw_api_cst a join fwk_user b on a.id_num = b.hostid
where a.jics_group_id = 'STU' and b.id not in (select MemberPrincipalID
from FWK_GroupMembership
where ParentPrincipalID = '9BF99855-F577-471F-8106-4B02CF91CB9B')
and a.ID_NUM in (select id_num from tmseprd.dbo.STUDENT_CRS_HIST
where YR_CDE = case when month(getdate()) >=8 then year(getdate()) else year(getdate())-1 end
and (DROP_FLAG is null or DROP_FLAG = '')
and STUD_DIV = 'UG')
"@

####################################################################################


try {
    $results = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $query -EnableException -ErrorAction Stop

    # Logging
    "[$(Get-Date)] JICS Query returned $($results.Count) rows" |
        Add-Content $LogFile

    # If any results are returned, alert and make a BBMsg file with a brief list of the results
    if ($results.Count -gt 0) {
        $BBcolor = "red"

        #$results | Get-Member

        $table = $results | 
            Select-Object FirstName, LastName, Email, ID_NUM, JICS_GROUP_ID |
            Format-Table -AutoSize |
            Out-String
        $BBMsg = @"
        There are $($results.Count) students found in this query.

        $table
"@  
}
    else {
        $BBcolor = "green"
        $BBMsg = "No students found in query."
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
