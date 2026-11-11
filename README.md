# VOID

VOID is an iOS security research assistant with an optional private on-device assistant mode.

## Local AI and system integration

- **VOID Local** uses Apple's on-device Foundation Models framework. It requires no provider API key and has no per-request API fee; the operating system manages model availability.
- **VOID Keyboard** is an optional system keyboard with local Improve, Shorten, and Translate actions for explicitly selected text. Keyboard open access is disabled and no text is sent to a server by these actions.
- **Ask VOID** is exposed through App Intents and App Shortcuts for Siri, Shortcuts, Spotlight, and supported system surfaces. On supported iPhones, a user can assign a VOID shortcut to the Action button.

The local model depends on device, language, region, and Apple Intelligence availability. It may be unavailable while iOS prepares the model.

## Research assistant

The agent chat can connect to a user-selected OpenAI-compatible model. Its available tools run on the iPhone: reading and organizing workspace files, searching the web, fetching technical references, querying SQLite read-only, and running JavaScript for calculations and workspace-only processing.

The first research workflow focuses on iOS kernel and sandbox security: researching advisories, reviewing source and patch differences, examining crash logs, querying SQLite databases read-only, and organizing reproducible findings.

The optional worse_query-style container bridge is device/OS dependent and not an App Store-safe feature. It is a scoped file-access mechanism, not root access, arbitrary filesystem access, process injection, or a code-signing bypass.

The current agent does not include a native kernel test runner, a shell, a debugger, or a general-purpose exploit engine. Dynamic tests require an explicitly authorized device or isolated harness, with results and logs supplied to the research workflow. File changes require user approval by default.

## Build

Requires the stupid-app CLI (0.0.27 or later).

```sh
swift test
stupid-app build
stupid-app run --simulator
```

Use stable dependency releases only. Device-only behavior must be tested on a real device; simulator results are not proof.
