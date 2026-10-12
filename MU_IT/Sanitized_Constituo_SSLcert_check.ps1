################################################################################
# Written by Jordan Beggs
# 
# Retrieve SSL cert properties from Constituo and alert Xymon of expire date
#      30 days warning, 7 days critical
#
# All variables marked with ~ ~ ~ ~ require input
#
################################################################################

# =====================
# Configuration
# =====================

# Constituo
$hostName = "" # ~ ~ ~ ~ 
$port = "" # ~ ~ ~ ~ 
$tcpClient = [System.Net.Sockets.TcpClient]::new($hostName,$port)

# Alert Threshold
$warningDays = 30
$criticalDays = 7

# Xymon
$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$serverName = "{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName
$testName = "sslcert" 
$color = "green"
$xymonHost = "" # ~ ~ ~ ~ 

# =====================
# SCRIPT EXECUTION
# =====================

try {
    # Set up tcp / ssl connection
    $sslStream = [System.Net.Security.SslStream]::new(
        $tcpClient.GetStream(),
        $false,
        { $true }
    )

    $sslStream.AuthenticateAsClient( 
        $hostname,
        $null,
        [System.Security.Authentication.SslProtocols]::Tls12,
        $false)

    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $sslStream.RemoteCertificate
    )

    # Calculate remaining days
    $daysLeft = (New-TimeSpan -Start (Get-Date) -End $cert.NotAfter).Days
    $expiryDate = $cert.NotAfter.ToString("yyyy-MM-dd")

    # Determine the status color
    if ($daysLeft -le $criticalDays) {
        $color = "red"
        $message = "CRITICAL: SSL Certificate expires in $daysLeft days on $expiryDate."
    } elseif ($daysLeft -le $warningDays) {
        $color = "yellow"
        $message = "WARNING: SSL Certificate expires in $daysLeft days on $expiryDate."
    } else {
        $color = "green"
        $message = "OK: SSL Certificate expires in $daysLeft days on $expiryDate."
    }

    # Add extra details for the Xymon status log
    $message += "`n`nSubject: $($cert.Subject)`nIssuer: $($cert.Issuer)`nThumbprint: $($cert.Thumbprint)"

} catch {
    $color = "red"
    $message = "CRITICAL: Failed to check SSL certificate. Error: $($_.Exception.Message)"
}

finally {
    $xymonMessage = "$serverName.$testName $color $(Get-Date)`n$message"
    & "C:\Program Files (x86)\BBWin\bin\bbwincmd.exe" $xymonHost status $serverName $testname $color $message 24h
    #Write-Host($xymonMessage)
    
    $sslStream.Dispose()
    $tcpClient.Dispose()
}