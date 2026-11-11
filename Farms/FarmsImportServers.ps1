###Find active broker and generate server list to import

Import-Module RemoteDesktop

$KnownBroker = "CHORCB01.cho.corp.ryanair.com" ###Chnage to rleevant broker.

# Discover the active management broker.
$HA = Get-RDConnectionBrokerHighAvailability `
    -ConnectionBroker $KnownBroker `
    -ErrorAction Stop

$Broker = $HA.ActiveManagementServer

if ([string]::IsNullOrWhiteSpace($Broker)) {
    throw "No active management broker returned. Inspect the HA configuration."
}

Write-Host "Active management broker: $Broker" -ForegroundColor Cyan

# Query first so a failed request doesn't overwrite the saved list.
$Servers = @(
    Get-RDServer -ConnectionBroker $Broker -ErrorAction Stop |
        Select-Object -ExpandProperty Server |
        Sort-Object -Unique
)

$Desktop = [Environment]::GetFolderPath("Desktop")
$File = Join-Path $Desktop "CHO-RDS-Servers.txt"

$Servers | Set-Content -Path $File -Encoding UTF8

Write-Host "Saved $($Servers.Count) servers to: $File"
