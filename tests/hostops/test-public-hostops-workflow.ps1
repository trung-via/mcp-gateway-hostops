#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$flowPath = Join-Path $root '.github/workflows/mcp-p2-provider-readonly.yml'
$scriptPath = Join-Path $root 'scripts/hostops/p2-ipv6-provider-controls-readonly.ps1'
if (-not (Test-Path -LiteralPath $flowPath -PathType Leaf)) { throw 'WORKFLOW_MISSING' }
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw 'SCRIPT_MISSING' }
$flow = Get-Content -LiteralPath $flowPath -Raw
$expectedBlob = '1172099c35eccb56d694d9a3c2f4fa3a145aced5'
$actualBlob = (& git -C $root rev-parse 'HEAD:scripts/hostops/p2-ipv6-provider-controls-readonly.ps1').Trim()
if ($LASTEXITCODE -ne 0 -or $actualBlob -cne $expectedBlob) { throw 'SOURCE_PIN_MISMATCH' }
foreach ($part in @(
  'issues:', 'types: [opened]', 'authorize-on-github-hosted:', 'runs-on: windows-latest',
  'execute-on-dedicated-windows:', 'needs: authorize-on-github-hosted',
  'runs-on: [self-hosted, windows, X64, mcp-gateway-hostops]',
  'trung-via/mcp-gateway-hostops', 'GITHUB_RUN_ATTEMPT', 'TotalSeconds -le 300',
  'GITHUB_ACTOR', 'event.sender.login', 'issue.user.login',
  "issue.body -ceq '{}'", 'MCP_P2_IPV6_PROVIDER_CONTROL_READONLY_V1',
  'MCP_P2_HOSTOPS_RECEIPT_V1=', $expectedBlob, 'RECEIPT_SCHEMA_DENY',
  'persist-credentials: false', 'contents: read', 'issues: write'
)) {
  if (-not $flow.Contains($part)) { throw ('REQUIRED_GUARD_MISSING_' + $part) }
}
if ($flow -match '(?im)^\s*(?:pull_request|pull_request_target|issue_comment|repository_dispatch|workflow_dispatch):\s*$') {
  throw 'UNTRUSTED_NATIVE_TRIGGER_FOUND'
}
if ($flow -notmatch 'uses:\s+actions/checkout@[0-9a-f]{40}') { throw 'CHECKOUT_NOT_PINNED' }
if ($flow -match '(?i)ai-commerce|cdp.?9444|new-netfirewallrule|start-process|invoke-expression') {
  throw 'CROSS_PROJECT_OR_HOST_MUTATION_FOUND'
}
if ($flow -match '(?im)^\s+run:\s*\$\{\{') { throw 'DYNAMIC_SHELL_FOUND' }
$jobs = @([regex]::Matches($flow, '(?m)^\s+[-]?\s*runs-on:\s*\[self-hosted,'))
if ($jobs.Count -ne 1) { throw 'UNEXPECTED_NATIVE_JOB_COUNT' }
Write-Output 'MCP_PUBLIC_HOSTOPS_STATIC_GUARDS=PASS'
