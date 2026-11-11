# VOID plan

## Goal

Build an iPhone-based iOS security research assistant focused first on kernel and sandbox behavior. VOID should help move from a research question to evidence: source review, advisory and patch research, crash-log triage, safe test planning, controlled validation, and a clear vulnerability report.

The model is user-configured through an OpenAI-compatible endpoint. Tool calls run on the iPhone within the app's actual capabilities and permissions.

## Current baseline

- Stable-only dependency policy. No alpha, beta or nightly packages in the stable branch.
- User-declared target baseline: iPhone 17 Pro Max on iOS 27.0.0. Treat this as the intended test target, not verified runtime state unless the connected device is confirmed.
- The existing worse_query-style bridge is already present in `SandboxBridge.swift` and `SandboxContainers.swift`; do not add a duplicate implementation.
- Other-app container access remains off by default and must be explicitly enabled by the user.
- File-change approval remains on by default.
- The VOID research profile separates hypotheses from reproduced findings and requires authorization and evidence.

## Available today

- Bring-your-own-model provider settings and Keychain-backed API key storage.
- Workspace file tools: read, write, edit, list, find and grep.
- Web search and page fetching for current technical references.
- JavaScript for calculations and workspace-only data processing.
- Read-only SQLite queries.
- Optional device-only app-container discovery and access through the existing private-API bridge.
- Conversation history, stop and retry.

## Research workflow

1. Establish target, ownership/authorization, scope and whether the task is static review or a dynamic test.
2. Gather primary sources: vendor advisories, source code, release notes, patches and technical papers.
3. Inspect supplied source, logs and databases without changing the target.
4. Design a minimal, non-destructive test in an isolated harness wherever possible.
5. Require explicit approval and a verified test setup before sensitive or state-changing actions.
6. Record evidence, environment, steps, expected/actual behavior and limitations.
7. Produce a report with impact, confidence, affected versions, mitigation and references.

## Next milestones

- Add a research workspace layout for sources, test plans, artifacts and findings.
- Add structured import and parsing for iOS crash logs and diagnostic reports.
- Add a safe local test-harness runner for user-owned sample projects, isolated from live system processes.
- Add reproducibility metadata and report export.
- Add source/advisory tracking and patch-diff comparison.

## Non-goals

- No stealth, persistence, unauthorized access, third-party app injection, exploit chaining, entitlement escalation or code-signing bypass.
- No automatic destructive tests against a daily-use phone.
- No claim of kernel/root execution or full filesystem access based only on container access.
