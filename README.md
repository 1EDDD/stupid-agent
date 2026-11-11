# VOID

VOID is an iOS security research assistant built on the stupid-agent architecture. It connects to a user-selected OpenAI-compatible model and runs its available tools on the iPhone.

The first research workflow focuses on iOS kernel and sandbox security: researching advisories, reviewing source and patch differences, examining crash logs, querying SQLite databases read-only, and organizing reproducible findings.

## Current capabilities

- Bring your own model through OpenAI-compatible providers.
- Read, search and organize files in the app's workspace.
- Search the web and fetch technical references.
- Run JavaScript for calculations and workspace-only data processing.
- Query SQLite databases in read-only mode.
- Optionally inspect other app containers through the existing worse_query-style bridge. This is device/OS dependent, disabled by default, and not an App Store-safe feature.
- Ask before changing files (enabled by default).

## Important limits

The current app does not include a native kernel test runner, a shell, a debugger, or a general-purpose exploit engine. It cannot claim to execute dynamic kernel or sandbox tests merely because it can inspect files. Dynamic tests require an explicitly authorized device or isolated harness, with results and logs supplied to the research workflow.

The container bridge is a scoped file-access mechanism, not root access, arbitrary filesystem access, process injection, or a code-signing bypass. Keep other-app access disabled unless needed and keep change approvals enabled.

## Build

Requires the `stupid-app` CLI (0.0.27 or later).

```sh
swift test
stupid-app build
stupid-app run --simulator
```

Use stable dependency releases only. Device-only behavior must be tested on a real device; simulator results are not proof of device compatibility.
