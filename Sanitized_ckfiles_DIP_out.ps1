# ==========================================
# CONFIGURATION
# All fields marked with <---> require input
# ==========================================

# 1. Search Path
$searchPath          = ""   # <--->

# 2. Constants
$textFileStatus = New-Item -Path "C:\Scripts\" -Name "dip_report3.txt" -ItemType "File"
$textFileTest = New-Item -Path "C:\Scripts\" -Name "dip_report4.txt" -ItemType "File"

$column = ""     # <--->
$serviceColor = "green"
$BBcolor = "green"
$xymonHost =  ""   # <--->

# 3. Get the server name
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$SERVERNAME = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

# ==========================================
# SCRIPT EXECUTION
# ==========================================

# Ensure staging directory exists
#if (-not (Test-Path $TempPath)) { New-Item -ItemType Directory -Path $TempPath | Out-Null }

try {

    # ---------------------------------------------------------
    # OUTGOING FOLDER DISCOVERY
    # ---------------------------------------------------------
    
    # Get subfolder names from root (filtering out . and ..)
    Get-ChildItem -Path $searchPath
    $Services = (Get-ChildItem -Path $searchPath -Directory).Name

    foreach ($Service in $Services) {
        Write-Host ("`n========================================")
        Write-Host (" PROCESSING SERVICE: $Service")
        Write-Host ("========================================")
        
        # We only care about monitoring the files queued in outgoing of Constituo
        $CurrentOutgoing = "$searchPath\$Service\outgoing"

        # We have the connection set up and the folder of outgoing files

        # ---------------------------------------------------------
        # CHECKING FILE MOD DATE/TIME
        # ---------------------------------------------------------
        Write-Host ("Checking Outgoing for $Service...")
        
        $Files = $null
        try { 
            $Files = Get-ChildItem -Path $CurrentOutgoing -File 
        } catch { 
            Write-Host ("    Could not access Outgoing for $Service.")
        }

        # Check each file's last write time, then alert if value is longer than 2 hours ago
        $numFiles = 0
        $serviceColor = "green"
        foreach ($File in $Files) {
            $FileModDate = (Get-Item -Path $File.FullName).LastWriteTime
            $FileModDateUTC = $FileModDate.ToUniversalTime()
            
            $TimeDiff = (Get-Date).ToUniversalTime() - $FileModDateUTC
            $MinDiff = $TimeDiff.TotalMinutes
            
            $numFiles++

            if ($MinDiff -gt 120) {
                $serviceColor = "red"
                $CleanName = $File.FullName
                Add-Content -Path $textFileStatus -Value "Status: $serviceColor! Filename: $CleanName  LastMod: $FileModDate <br>" -NoNewline
            } else {
                $serviceColor = "green"
            } 
        }

        #List all file paths
        Add-Content -Path $textFileTest -Value "`nStatus: $serviceColor! $numFiles Files in: $CurrentOutgoing"
    }

    # Combine list of red files and list of all file paths searched

    $message1 = [IO.File]::ReadAllText("C:\Scripts\dip_report3.txt")
    $message2 = [IO.File]::ReadAllText("C:\Scripts\dip_report4.txt")
    $BBMSG1 = $message1 + $message2

    if ($message2 -match 'red') { $BBcolor = "red" }
    
    & "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost status $SERVERNAME $column $BBcolor $BBMSG1
    #Write-Host ("status $SERVERNAME $column $BBcolor $BBMSG1")
}

catch {
    Write-Host("Critical Script Failure: $($_.Exception.Message)")
}
finally {
    erase $textFileStatus
    erase $textFileTest
}