#Requires -Version 7.0
<#
.SYNOPSIS
  MCP Gateway HostOps: one fixed, read-only IPv6 provider positive-control.
.DESCRIPTION
  No arguments, no host diagnostics, no Caddy/firewall/listener mutations.
  Contacts TCPData and Check-Host solely about the public test endpoint
  ipv6.google.com:443. Emits ONE sanitized receipt line; no raw response data.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$receipt = [ordered]@{
    schema = 'MCP_P2_HOSTOPS_RECEIPT_V1'
    operation = 'MCP_P2_IPV6_PROVIDER_CONTROL_READONLY_V1'
    utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    status = 'CONTROLS_BLOCKED'
    tcpdata_status = 'PROVIDER_ERROR'
    tcpdata_error = 'NONE'
    checkhost_status = 'PROVIDER_ERROR'
    checkhost_error = 'NONE'
    checkhost_selected_nodes = 0
    checkhost_ipv6_nodes = 0
    checkhost_ipv4_nodes = 0
    checkhost_error_nodes = 0
    checkhost_pending_nodes = 0
    checkhost_schema_nodes = 0
    checkhost_distinct_asns = 0
}

$headers = @{ Accept = 'application/json' }
$tcpStage = 'REQUEST'
try {
    # Fixed public control only. Never supply laptop hostname or literal IPv6.
    $response = Invoke-WebRequest -Uri 'https://tcpdata.com/port?host=ipv6.google.com&port=443' -Headers $headers -TimeoutSec 12 -ErrorAction Stop
    $tcpStage = 'HTTP'
    if ($response.StatusCode -ne 200) { throw 'UNEXPECTED_HTTP' }
    $tcpStage = 'SCHEMA'
    $json = $response.Content | ConvertFrom-Json -ErrorAction Stop
    $status = [string]$json.status
    if ($status -notin @('open', 'closed', 'timeout')) { throw 'UNEXPECTED_STATUS' }
    $receipt['tcpdata_status'] = $status.ToUpperInvariant()
}
catch {
    # Intentionally redact exception message, raw response, IPs and URLs.
    $receipt['tcpdata_error'] = 'TCPDATA_' + $tcpStage + '_FAILED'
}

$checkStage = 'START_REQUEST'
try {
    $start = Invoke-RestMethod -Uri 'https://check-host.net/check-tcp?host=ipv6.google.com%3A443&max_nodes=8' -Headers $headers -TimeoutSec 8 -ErrorAction Stop
    $checkStage = 'START_SCHEMA'
    if ([int]$start.ok -ne 1 -or [string]::IsNullOrWhiteSpace([string]$start.request_id) -or $null -eq $start.nodes) {
        throw 'BAD_START'
    }
    $requestId = [string]$start.request_id
    if ($requestId -notmatch '^[a-zA-Z0-9_-]{1,80}$') { throw 'BAD_REQUEST_ID' }
    $nodes = @($start.nodes.PSObject.Properties)
    if ($nodes.Count -lt 1 -or $nodes.Count -gt 8) { throw 'BAD_NODE_COUNT' }
    foreach ($node in $nodes) {
        if ($node.Name -notmatch '^[a-z0-9-]+\.node\.check-host\.net$') { throw 'BAD_NODE_ID' }
    }
    $receipt['checkhost_selected_nodes'] = $nodes.Count

    $url = 'https://check-host.net/check-result/' + [uri]::EscapeDataString($requestId)
    $data = $null
    $checkStage = 'RESULT_REQUEST'
    for ($attempt = 0; $attempt -lt 6; $attempt++) {
        Start-Sleep -Seconds 1
        $data = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 5 -ErrorAction Stop
        if ($null -eq $data) { continue }
        $pending = 0
        foreach ($node in $nodes) {
            $item = $data.PSObject.Properties[$node.Name]
            if ($null -eq $item -or $null -eq $item.Value) { $pending++ }
        }
        if ($pending -eq 0) { break }
    }

    $checkStage = 'RESULT_SCHEMA'
    $asns = @()
    foreach ($node in $nodes) {
        $item = if ($null -ne $data) { $data.PSObject.Properties[$node.Name] } else { $null }
        if ($null -eq $item -or $null -eq $item.Value) {
            $receipt['checkhost_pending_nodes']++
            continue
        }
        $category = 'SCHEMA'
        foreach ($hit in @($item.Value)) {
            if ($null -eq $hit) { continue }
            $errorProp = $hit.PSObject.Properties['error']
            if ($null -ne $errorProp) {
                $category = 'ERROR'
                break
            }
            $addressProp = $hit.PSObject.Properties['address']
            $timeProp = $hit.PSObject.Properties['time']
            if ($null -eq $addressProp -or $null -eq $timeProp -or $null -eq $timeProp.Value) { continue }
            try {
                $ip = [System.Net.IPAddress]::Parse([string]$addressProp.Value)
                if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
                    $category = 'IPV6'
                    break
                }
                if ($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
                    $category = 'IPV4'
                    break
                }
            }
            catch {
                # Failed to parse provider-supplied destination: schema category only.
            }
        }
        switch ($category) {
            IPV6 {
                $receipt['checkhost_ipv6_nodes']++
                $meta = @($node.Value)
                if ($meta.Count -ge 5 -and [string]$meta[4] -match '^AS[0-9]+$') {
                    $asns += [string]$meta[4]
                }
            }
            IPV4   { $receipt['checkhost_ipv4_nodes']++ }
            ERROR  { $receipt['checkhost_error_nodes']++ }
            default { $receipt['checkhost_schema_nodes']++ }
        }
    }
    $receipt['checkhost_distinct_asns'] = @($asns | Sort-Object -Unique).Count
    $receipt['checkhost_status'] = 'RESULTS_CLASSIFIED'
}
catch {
    $receipt['checkhost_error'] = 'CHECKHOST_' + $checkStage + '_FAILED'
}

if ($receipt['tcpdata_status'] -eq 'OPEN' -and $receipt['checkhost_distinct_asns'] -ge 2) {
    $receipt['status'] = 'CONTROLS_PASS'
}

# Exactly one machine-parseable, allowlisted line. No raw third-party payload.
Write-Output ('MCP_P2_HOSTOPS_RECEIPT_V1=' + ($receipt | ConvertTo-Json -Compress -Depth 3))
