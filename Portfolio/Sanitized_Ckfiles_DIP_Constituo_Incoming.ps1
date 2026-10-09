Import-Module "F:\Malone\Powershell Projects\ConstituoSMBSFTPBridge\lib\Posh-SSH\3.2.7\Posh-SSH.psd1" 

# =================================================
# CONFIGURATION
#
# All variables marked with ~ ~ ~ ~ require input
# =================================================

# 1. SFTP Server Settings
$SftpHost          = "" # ~ ~ ~ ~
$SftpUser          = "" # ~ ~ ~ ~
$SftpKeyPath       = "" # ~ ~ ~ ~
$SftpKeyPassphrase = "" # ~ ~ ~ ~
# The base directory on the SFTP where various service folders reside
$SftpRoot          = "/" 

# 2. Intermediate Local Storage
$TempPath          = "" # ~ ~ ~ ~

# 3. Constants
$textFileStatus = New-Item -Path "C:\Scripts\" -Name "dip_report3.txt" -ItemType "File"
$textFileTest = New-Item -Path "C:\Scripts\" -Name "dip_report4.txt" -ItemType "File"

$xymonHost = "" # ~ ~ ~ ~
$column = "DIP_in" 
$serviceColor = "green"
$BBcolor = "green"

# 4. Get the server name
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$SERVERNAME = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName

# ==========================================
# SCRIPT EXECUTION
# ==========================================

# Ensure staging directory exists
if (-not (Test-Path $TempPath)) { New-Item -ItemType Directory -Path $TempPath | Out-Null }

$SecPassphrase = ConvertTo-SecureString $SftpKeyPassphrase -AsPlainText -Force
$SftpCred      = New-Object System.Management.Automation.PSCredential($SftpUser, $SecPassphrase)

try {
    Write-Host "Connecting to $SftpHost via SFTP..." -ForegroundColor Cyan
    $Session = New-SFTPSession -ComputerName $SftpHost `
                               -Credential $SftpCred `
                               -KeyFile $SftpKeyPath `
                               -AcceptKey

    # ---------------------------------------------------------
    # CONSTITUO INCOMING FOLDER DISCOVERY
    # ---------------------------------------------------------
    
    # Get subfolder names from SFTP root (filtering out . and ..)
    $Services = Get-SFTPChildItem -SessionId $Session.SessionId -Path $SftpRoot | 
                   Where-Object { $_.IsDirectory -and $_.Name -notmatch "^\.+$" } | 
                   Select-Object -ExpandProperty Name

    foreach ($Service in $Services) {
        Write-Host ("`n========================================")
        Write-Host (" PROCESSING SERVICE: $Service")
        Write-Host ("========================================")
        
        # SFTP paths use forward slashes (ensure lower/upper case matches your SFTP server)
        # We only care about monitoring the files queued in incoming of Constituo
        $CurrentSftpIncoming = "$SftpRoot/$Service/incoming"

        # We have the connection set up and the folder of incoming files

        # ---------------------------------------------------------
        # CHECKING FILE MOD DATE/TIME
        # ---------------------------------------------------------
        Write-Host ("Checking SFTP Incoming for $Service...")
        
        # Wrap SFTP check in try/catch in case the service folder doesn't exist on SFTP side yet
        $SftpFiles = $null
        try { 
            $SftpFiles = Get-SFTPChildItem -SessionId $Session.SessionId -Path $CurrentSftpIncoming -File 
        } catch { 
            Write-Host ("    Could not access SFTP Incoming for $Service.")
        }

        # Check each file's last write time, then alert if value is longer than 24 hours ago
        $numFiles = 0
        $serviceColor = "green"
        foreach ($SFile in $SftpFiles) {
            $FileModDate = (Get-SFTPPathAttribute -SessionId $Session.SessionId -Path $SFile.FullName).LastWriteTime
            $FileModDateUTC = $FileModDate.ToUniversalTime()
            
            $TimeDiff = (Get-Date).ToUniversalTime() - $FileModDateUTC
            $MinDiff = $TimeDiff.TotalMinutes

            if ($MinDiff -gt 1440) {
                $serviceColor = "red"
                $numFiles++
                $CleanName = $SFile.FullName
                Add-Content -Path $textFileStatus -Value "Status: $serviceColor! $numFiles Filename: $CleanName  LastMod: $FileModDate <br>" -NoNewline
            } else {
                $serviceColor = "green"
            } 
        }

        #List all file paths
        Add-Content -Path $textFileTest -Value "`nStatus: $serviceColor! $numFiles Files in: $CurrentSftpIncoming"
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
    Write-Host "Message: $($_.Exception.Message)"
    Write-Host "Type:    $($_.Exception.GetType().FullName)"
    Write-Host "Inner:   $($_.Exception.InnerException)"
}
finally {
    #if ($Session) {
        #terminate session
        Write-Host ("`nTerminating SFTP Session.")
        Remove-SFTPSession -SessionId $Session.SessionId
        erase $textFileStatus
        erase $textFileTest
    #}
}
