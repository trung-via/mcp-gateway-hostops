#Requires -Version 7.0
# Offline mocked HostOps P2 provider controls; NEVER calls third-party APIs.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot '../../scripts/hostops/p2-ipv6-provider-controls-readonly.ps1'
$source = (Resolve-Path -LiteralPath $source).Path
$sourceText = Get-Content -LiteralPath $source -Raw
$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseInput($sourceText, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -gt 0) { throw 'SOURCE_POWERSHELL_SYNTAX_ERROR' }

# No host state, arbitrary execution, unsafe networking or dynamic commands.
foreach ($forbidden in @(
    'New-NetFirewallRule', 'Set-NetFirewallRule', 'Remove-NetFirewallRule',
    'Start-Process', 'Stop-Process', 'Invoke-Expression', 'Get-NetIPAddress',
    'Get-NetTCPConnection', 'Set-DnsClientServerAddress', 'New-ItemProperty',
    'Invoke-Command', 'Enter-PSSession', 'Start-Job'
)) {
    if ($sourceText.Contains($forbidden)) { throw ('FORBIDDEN_HOST_OPERATION_' + $forbidden) }
}
if ($sourceText -notmatch "ipv6\.google\.com" -or $sourceText -notmatch "tcpdata\.com" -or $sourceText -notmatch "check-host\.net") {
    throw 'EXPECTED_FIXED_PROVIDER_HOSTS_MISSING'
}

$global:McpHostopsScenario = ''
$global:McpHostopsUris = @()
function global:Invoke-WebRequest {
    [CmdletBinding()]
    param([string] $Uri, $Headers, [int] $TimeoutSec)
    $global:McpHostopsUris += $Uri
    if ($Uri -ne 'https://tcpdata.com/port?host=ipv6.google.com&port=443') { throw 'UNAUTHORIZED_TCPDATA_URI' }
    if ($global:McpHostopsScenario -eq 'tcpdata_request_error') { throw 'MOCK_HTTP_FAIL' }
    $status = if ($global:McpHostopsScenario -eq 'tcpdata_timeout') { 'timeout' } else { 'open' }
    return [pscustomobject]@{ StatusCode = 200; Content = ('{"status":"' + $status + '"}') }
}
function global:Invoke-RestMethod {
    [CmdletBinding()]
    param([string] $Uri, $Headers, [int] $TimeoutSec)
    $global:McpHostopsUris += $Uri
    if ($Uri -eq 'https://check-host.net/check-tcp?host=ipv6.google.com%3A443&max_nodes=8') {
        if ($global:McpHostopsScenario -eq 'checkhost_bad_start') { return '{"ok":0}' | ConvertFrom-Json }
        $asn2 = if ($global:McpHostopsScenario -eq 'same_asn') { 'AS100' } else { 'AS200' }
        return ('{"ok":1,"request_id":"fixture","nodes":{"us1.node.check-host.net":["us","USA","NY","203.0.113.1","AS100"],"de1.node.check-host.net":["de","Germany","Berlin","203.0.113.2","' + $asn2 + '"]}}') | ConvertFrom-Json
    }
    if ($Uri -ne 'https://check-host.net/check-result/fixture') { throw 'UNAUTHORIZED_CHECKHOST_URI' }
    if ($global:McpHostopsScenario -eq 'ipv4_only') {
        return '{"us1.node.check-host.net":[{"time":0.03,"address":"8.8.8.8"}],"de1.node.check-host.net":[{"time":0.02,"address":"1.1.1.1"}]}' | ConvertFrom-Json
    }
    if ($global:McpHostopsScenario -eq 'error_pending') {
        return '{"us1.node.check-host.net":[{"error":"Connection timed out"}],"de1.node.check-host.net":null}' | ConvertFrom-Json
    }
    return '{"us1.node.check-host.net":[{"time":0.03,"address":"2001:4860:4860::8888"}],"de1.node.check-host.net":[{"time":0.04,"address":"2606:4700:4700::1111"}]}' | ConvertFrom-Json
}
function global:Start-Sleep {
    param([int] $Seconds)
    # Eliminate polling delay in offline fixture only.
}
function Read-Fixture {
    param([string] $Mode)
    $global:McpHostopsScenario = $Mode
    $global:McpHostopsUris = @()
    if ((Get-Command Invoke-WebRequest).CommandType -ne 'Function' -or (Get-Command Invoke-RestMethod).CommandType -ne 'Function') { throw 'MISSING_MOCK' }
    $lines = @(& $source)
    if ($lines.Count -ne 1 -or -not ([string]$lines[0]).StartsWith('MCP_P2_HOSTOPS_RECEIPT_V1=')) {
        throw ('BAD_RECEIPT_FOR_' + $Mode)
    }
    $receipt = ([string]$lines[0]).Substring('MCP_P2_HOSTOPS_RECEIPT_V1='.Length) | ConvertFrom-Json
    if ($receipt.schema -ne 'MCP_P2_HOSTOPS_RECEIPT_V1') { throw ('BAD_SCHEMA_FOR_' + $Mode) }
    foreach ($uri in $global:McpHostopsUris) {
        if ($uri -notin @(
            'https://tcpdata.com/port?host=ipv6.google.com&port=443',
            'https://check-host.net/check-tcp?host=ipv6.google.com%3A443&max_nodes=8',
            'https://check-host.net/check-result/fixture'
        )) { throw 'NON_ALLOWLIST_URI' }
    }
    return $receipt
}

$r = Read-Fixture 'two_ipv6_asns'
if ($r.status -ne 'CONTROLS_PASS' -or $r.checkhost_distinct_asns -ne 2 -or $r.checkhost_ipv6_nodes -ne 2) {
    throw ('TWO_ASNS_POSITIVE_FAILED MOCK_CALL_COUNT=' + $global:McpHostopsUris.Count + ' RECEIPT=' + ($r | ConvertTo-Json -Compress -Depth 3))
}
$r = Read-Fixture 'same_asn'
if ($r.status -ne 'CONTROLS_BLOCKED' -or $r.checkhost_distinct_asns -ne 1 -or $r.checkhost_ipv6_nodes -ne 2) {
    throw 'SAME_ASN_NEGATIVE_FAILED'
}
$r = Read-Fixture 'ipv4_only'
if ($r.status -ne 'CONTROLS_BLOCKED' -or $r.checkhost_ipv4_nodes -ne 2 -or $r.checkhost_ipv6_nodes -ne 0) {
    throw 'IPV4_NEGATIVE_FAILED'
}
$r = Read-Fixture 'error_pending'
if ($r.status -ne 'CONTROLS_BLOCKED' -or $r.checkhost_pending_nodes -ne 1 -or $r.checkhost_error_nodes -ne 1) {
    throw 'ERROR_PENDING_NEGATIVE_FAILED'
}
$r = Read-Fixture 'checkhost_bad_start'
if ($r.checkhost_error -ne 'CHECKHOST_START_SCHEMA_FAILED' -or $r.checkhost_status -ne 'PROVIDER_ERROR') {
    throw 'SCHEMA_NEGATIVE_FAILED'
}
$r = Read-Fixture 'tcpdata_timeout'
if ($r.tcpdata_status -ne 'TIMEOUT' -or $r.status -ne 'CONTROLS_BLOCKED') {
    throw 'TCPDATA_TIMEOUT_NEGATIVE_FAILED'
}
$r = Read-Fixture 'tcpdata_request_error'
if ($r.tcpdata_error -ne 'TCPDATA_REQUEST_FAILED' -or $r.tcpdata_status -ne 'PROVIDER_ERROR') {
    throw 'TCPDATA_REQUEST_NEGATIVE_FAILED'
}
Write-Output 'P2_HOSTOPS_OFFLINE_FIXTURE_TESTS=PASS'
