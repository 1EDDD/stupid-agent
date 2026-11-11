# VOID

VOID is an iOS security research assistant with a private, multilingual on-device assistant mode.

## Local AI and system integration

- **VOID Local** uses Qwen3 0.6B through Apple's Core AI runtime on iOS 27. It supports 100+ languages, including Arabic. No provider API key or per-request API fee is used. The iPhone model bundle downloads once on first use (approximately 456 MB) and is cached for later offline use.
- **Ask VOID** is exposed through App Intents and App Shortcuts for Siri, Shortcuts, Spotlight, and supported system surfaces. A user can also assign an App Shortcut to the iPhone Action button on supported devices.
- **VOID Keyboard** is an optional system keyboard with Improve, Shorten, and Translate actions for explicitly selected text. It uses Apple's smaller system model to respect keyboard-extension memory limits; for Arabic AI requests, use VOID Local or Ask VOID instead. Keyboard open access is disabled and selected text is not sent to a server.

iOS does not allow a third-party app to replace Siri globally, read every other app's screen, or run unrestricted background code. The keyboard is available only in text fields that allow third-party keyboards; secure fields keep the system keyboard.

## Research assistant

The agent chat can connect to a user-selected OpenAI-compatible model. Its available tools run on the iPhone: reading and organizing workspace files, searching the web, fetching technical references, querying SQLite read-only, and running JavaScript for calculations and workspace-only processing.

The first research workflow focuses on iOS kernel and sandbox security: researching advisories, reviewing source and patch differences, examining crash logs, querying SQLite databases read-only, and organizing reproducible findings.

The optional worse_query-style container bridge is device/OS dependent and is not an App Store-safe feature. It is a scoped file-access mechanism, not root access, arbitrary filesystem access, process injection, or a code-signing bypass.

The current agent does not include a native kernel test runner, a shell, a debugger, or a general-purpose exploit engine. Dynamic tests require an explicitly authorized device or isolated harness, with results and logs supplied to the research workflow. File changes require user approval by default.

## Build

Requires the stupid-app CLI (0.0.27 or later) and Xcode 27 for the Core AI target.

```sh
swift test
stupid-app build
stupid-app run --simulator
```

Use a real iOS 27 device to test Core AI inference. Simulator results are not proof of device inference.
