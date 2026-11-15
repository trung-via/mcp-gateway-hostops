# MCP Gateway HostOps

Public repository for the **independent, owner-operated Windows HostOps channel** of [MCP Gateway](https://github.com/trung-via/mcp-gateway). It does not reuse AI Commerce, CDP Host, or any other project's runner, credentials, or worktree.

## Current configuration

- GitHub owner: `trung-via`; repository: **Public** by owner decision (2026-11-15).
- Source and offline tests for the fixed `MCP_P2_IPV6_PROVIDER_CONTROL_READONLY_V1` operation are on the bootstrap branch until independently verified and merged.
- The owner-only GitHub Issue workflow first checks the authenticated sender on a GitHub-hosted Windows runner. Only a valid, fresh, exact zero-input request can queue the dedicated self-hosted Windows job.
- The native job accepts **no arbitrary command, URL, script path, or host target**. It verifies the source Git blob before running and posts only a bounded redacted receipt to its Issue.
- GitHub workflow/CI tests **do not establish a connection to the Windows laptop**. A distinct runner with label `mcp-gateway-hostops` has not yet been verified enrolled.

## Operator intent

The owner approved public source and requests broad MCP Gateway HostOps operational authority. The initial installed operation is deliberately a fixed read-only provider check; adding mutating Windows operations requires individually defined code/contracts and native receipts. Do not confuse a GitHub repository admin permission with Windows Administrator elevation.

## Live dispatch (after native enrollment)

Create exactly one Issue in this repository:
- Title: `MCP_P2_IPV6_PROVIDER_CONTROL_READONLY_V1`
- Body: exactly `{}`
- Author: `trung-via`

Only a new Issue on `main` within five minutes, first attempt, with the expected identity and exact body passes the hosted gate. The fixed public target is `ipv6.google.com:443`, checked via TCPData and Check-Host; no user IPv6, hostname, token, process path or local firewall state is posted.

See [operations and enrollment](docs/hostops-control-plane.md). Do not activate the native workflow before reviewing the PR and enrolling a dedicated owner-controlled Windows runner.
