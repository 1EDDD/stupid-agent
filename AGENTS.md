# VOID

An iOS security research assistant built on the stupid-agent app architecture. It uses a user-configured OpenAI-compatible model and the iPhone tools already available to the app.

## Before changing anything

- Read `docs/PLAN.md` and `docs/IMPLEMENTATION.md`.
- Agent behavior belongs in swift pi; update the dependency through a stable release and commit `Package.resolved`. Chat behavior belongs in stupid chatkit.
- Keep `Sources/StupidAgentCore/VOIDResearchProfile.swift` aligned with the real tools. Prompt instructions are not a substitute for code-level permission checks.

## Project structure

```
Sources/
  StupidAgent/              # SwiftUI screens (iOS only)
    StupidAgent.swift
    ConversationsView.swift
    AgentChatView.swift
    AgentChatAdapter.swift
    SettingsView.swift
    SandboxBridge.swift     # Existing worse_query-style container bridge
    SandboxContainers.swift
    ContainerIndex.swift
  StupidAgentCore/
    VOIDResearchProfile.swift
    ModelSettings.swift
    Keychain.swift
    ConversationStore.swift
    ChatEntries.swift
    AppContainers.swift
    SQLiteTool.swift
    AgentSession.swift
Tests/StupidAgentCoreTests/
```

## Stack and style

- Swift 6, SwiftUI, Observation, iOS 18.
- Use stable package releases only. No alpha, beta or nightly dependencies on the stable branch.
- Preserve the existing bundle identifier and App Group identifier unless a migration is deliberately planned; the App Group is tied to signing and the sandbox bridge.
- Read `docs/IMPLEMENTATION.md` before changing the bridge. It uses private APIs and has device/OS-specific behavior.

## Security and testing boundaries

- Test only devices, apps, accounts and data the user owns or is explicitly authorized to assess.
- Treat other-app container inspection as read-only by default. Keep `Access Other Apps` off unless the user enables it, and keep file-change approval enabled.
- The worse_query-style bridge grants access to particular containers. It is not root, arbitrary filesystem access, kernel privilege or process injection.
- Prefer static analysis, crash-log triage, patch review and isolated test harnesses. Do not add stealth, persistence, exploit chains, entitlement/signing bypasses or third-party process injection.
- Never claim a live-device test ran unless it actually ran and evidence is available.

## Build and test

- `swift test` runs core tests.
- `stupid-app build` builds the app.
- Do not claim a build or device test passed unless it was run.

## Before committing

- Update `docs/IMPLEMENTATION.md`; assume documentation is public and never include personal information.
- Commit messages in this repository must be exactly `67`.
