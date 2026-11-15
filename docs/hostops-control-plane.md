# Dedicated public MCP Gateway HostOps control plane

**Owner decision (2026-11-15):** keep this project independent of AI Commerce and use a **Public** GitHub repository. The previous private-repository plan in MCP Gateway's draft PR #10 is superseded for deployment targeting; canonical source will be reconciled separately.

## Configuration and boundaries

| Layer | Mechanism | Current evidence |
| --- | --- | --- |
| Identity | GitHub repository owner `trung-via` | Connector identity and repo admin metadata verified |
| Source | Separate public repository, `main` + reviewed bootstrap PR | Repository created |
| Admission | Issue `opened`, exact title/body, owner/sender/actor, 5-minute freshness, first attempt | Workflow source only until merged |
| Execution | Dedicated self-hosted Windows runner `mcp-gateway-hostops`, PowerShell 7 | **NOT VERIFIED / NOT ENROLLED** |
| Receipt | Fixed schema in same GitHub Issue; count/status only | Code only; no laptop receipt |
| Scope | MCP Gateway only, no shared AI Commerce/CDP Host runner | Source-owned controls |

The owner has requested broad HostOps authority. This is authorization **for implementing and using a dedicated MCP Gateway channel**, not proof that a Windows runner or OS administrator session exists. No access control may be derived from freeform Issue content.

## Fixed bootstrap operation

`MCP_P2_IPV6_PROVIDER_CONTROL_READONLY_V1` has exact parameters `{}`. It tests a known public positive-control endpoint `ipv6.google.com:443` with TCPData and Check-Host, to separate external checker capability failure from the laptop's own IPv6 ingress. It does not disclose or probe the laptop IPv6. The reviewed Git blob must equal `1172099c35eccb56d694d9a3c2f4fa3a145aced5`.

The workflow uses GitHub-hosted Windows for admission and a separate Windows host job only after PASS. Never execute untrusted pull-request content or use Issue text as shell code. Self-hosted runners in public repositories carry a documented attack surface: keep the repository owner-only for write access and add no untrusted PR workflow triggers.

## Native enrollment gate

The current ChatGPT GitHub connector can write repository files, Issues and PRs; it does **not** provide a runner-registration or Windows command-execution API. The agent must verify an independent native route before declaring the service active:

1. Acquire an explicit authorized **native Windows execution mechanism** for this repository (not an AI Commerce credential). Use it to install/enroll an isolated runner under a separate Windows account/workdir, with label `mcp-gateway-hostops`.
2. Verify the runner shows online and tied to `trung-via/mcp-gateway-hostops`; record job URL/runner identity without exposing enrollment tokens.
3. Merge the reviewed workflow and tests after GitHub-hosted Windows CI passes.
4. Create one exact owner-authored Issue with title `MCP_P2_IPV6_PROVIDER_CONTROL_READONLY_V1` and body `{}`.
5. Independently read the two-stage job, native script result and count-only Issue receipt. Missing native job/receipt means **BLOCKED**, never PASS.

Do not ask the human to run diagnostic PowerShell as fallback. If host enrollment itself needs a new credential, remote-control grant, or local native tool, report that specific blocker and ask for that access, not an arbitrary PowerShell transcript.

## Separate authorizations

No fourth ACME trial, public MCP endpoint exposure, persistent firewall changes, Caddy deployment, router changes or CDP 9444 access are authorized by the existence of this bootstrap. These require dedicated operations and explicit purpose/rollback even under the owner's broad operational policy.
