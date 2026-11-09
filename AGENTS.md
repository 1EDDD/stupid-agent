# stupid agent

An iOS app for a bring-your-own-model agent that runs on the device: the user sets an OpenAI-compatible server, key
and model, and the agent executes tool calls on the phone against the app's workspace folder. Built on swift pi
(github.com/stephancill/swift-pi), a Swift port of pi.

## Before changing anything

- Read `docs/PLAN.md` for product direction and `docs/IMPLEMENTATION.md` for the current state and decisions.
- Agent behavior (loop, providers, tools) belongs in swift pi, not here: change it in `../swift-pi`, tag a release,
  then run `scripts/vendor-swift-pi.sh <tag>`. Never edit `Vendor/SwiftPi` by hand.

## Project structure

```
Sources/
  StupidAgent/            # SwiftUI screens (iOS only)
    StupidAgent.swift     # @main and AppModel: settings, workspace, sessions, conversation list
    ConversationsView.swift
    ChatView.swift        # Chat screen; a placeholder until it moves to stupid chatkit
    SettingsView.swift    # Bring-your-own-model settings
  StupidAgentCore/        # No UI; tested with `swift test` on macOS
    ModelSettings.swift   # Provider presets, ModelSettings, SettingsStore, model listing
    Keychain.swift
    ConversationStore.swift
    ChatItems.swift       # Transcript → display rows
    AgentSession.swift    # One conversation: the swift pi Agent, file-change approvals, saving
Vendor/SwiftPi/          # swift pi sources at a tag (scripts/vendor-swift-pi.sh)
Tests/StupidAgentCoreTests/
```

Keep this section in sync when files are added, moved or renamed.

## Stack and style

- Swift 6, SwiftUI, Observation, iOS 18. Built and run with the `stupid-app` CLI, which builds only local sources:
  dependencies are vendored, never remote SwiftPM packages.
- Follow the stupid iOS design rules: native components, no monospaced fonts, at most two font sizes per group,
  centered `.alert` confirmations for destructive actions.
- UI files are wrapped in `#if os(iOS)` so `swift test` can build the package on macOS.
- Prefer failing loudly over fallbacks. The one deliberate exception is the simulator-only API key storage in
  `SettingsStore` (see `docs/IMPLEMENTATION.md`).
- Named parameters, value types, `@MainActor @Observable` for UI state.

## Build, test, run

- `swift test` runs the core tests.
- `stupid-app build` after source changes; `stupid-app run --simulator` to install. Follow the simulator claim rules in
  the user's global instructions before using a simulator.

## Before committing

- Update `docs/IMPLEMENTATION.md` to describe the current state. Never include personal information: assume it is public.
- Conventional commits (`feat:`, `fix:`, `chore:`, ...).
