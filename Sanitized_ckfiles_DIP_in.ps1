# ==========================================
# CONFIGURATION
# All fields marked with <---> require input
# ==========================================

# 1. Search Path
$searchPath          = ""   # <--->

# 2. Constants
$textFileStatus = New-Item -Path "C:\Scripts\" -Name "dip_report1.txt" -ItemType "File"
$textFileTest = New-Item -Path "C:\Scripts\" -Name "dip_report2.txt" -ItemType "File"

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
    # INCOMING FOLDER DISCOVERY
    # ---------------------------------------------------------
    
    # Get subfolder names from root (filtering out . and ..)
    Get-ChildItem -Path $searchPath
    $Services = (Get-ChildItem -Path $searchPath -Directory).Name

    foreach ($Service in $Services) {
        Write-Host ("`n========================================")
        Write-Host (" PROCESSING SERVICE: $Service")
        Write-Host ("========================================")
        
        # We only care about monitoring the files queued in incoming of Constituo
        $CurrentIncoming = "$searchPath\$Service\incoming"

        # We have the connection set up and the folder of incoming files

        # ---------------------------------------------------------
        # CHECKING FILE MOD DATE/TIME
        # ---------------------------------------------------------
        Write-Host ("Checking Incoming for $Service...")
        
        # Wrap SFTP check in try/catch in case the service folder doesn't exist on SFTP side yet
        $Files = $null
        try { 
            $Files = Get-ChildItem -Path $CurrentIncoming -File 
        } catch { 
            Write-Host ("    Could not access Incoming for $Service.")
        }

        # Check each file's last write time, then alert if value is longer than 24 hours ago
        $numFiles = 0
        $serviceColor = "green"
        foreach ($File in $Files) {
            $FileModDate = (Get-Item -Path $File.FullName).LastWriteTime
            $FileModDateUTC = $FileModDate.ToUniversalTime()
            
            $TimeDiff = (Get-Date).ToUniversalTime() - $FileModDateUTC
            $MinDiff = $TimeDiff.TotalMinutes
            
            $numFiles++

            if ($MinDiff -gt 1440) {
                $serviceColor = "red"
                $CleanName = $File.FullName
                Add-Content -Path $textFileStatus -Value "Status: $serviceColor! Filename: $CleanName  LastMod: $FileModDate <br>" -NoNewline
            } else {
                $serviceColor = "green"
            } 
        }

        #List all file paths
        Add-Content -Path $textFileTest -Value "`nStatus: $serviceColor! $numFiles Files in: $CurrentIncoming"
    }

    # Combine list of red files and list of all file paths searched

    $message1 = [IO.File]::ReadAllText("C:\Scripts\dip_report1.txt")
    $message2 = [IO.File]::ReadAllText("C:\Scripts\dip_report2.txt")
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