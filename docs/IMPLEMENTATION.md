# Implementation notes

## Agent core

- **Source:** swift pi, a package dependency pinned in `Package.resolved`. It was vendored while stupid-app built only local sources; stupid-app 0.0.27 resolves package dependencies.
- **Session:** `AgentSession` owns one swift pi `Agent`:
  - its system prompt is `systemPrompt(workspaceName:)`
  - its tools are `fileTools(workspace:)`
  - its transcript is the conversation's
- **Messages:** the agent's event stream is the only source of `AgentSession.messages`. The run finishes, and the conversation is saved, when the `agentEnd` event is handled. An earlier version replaced `messages` with the agent's state after `prompt()` returned. Events still queued then were appended again, which duplicated replies.
- **Sending while running:** a message sent while the agent runs goes to `Agent.steer`. It is read after the current tool calls, before the next request.
- **Retry:** drops the failed responses at the end of the agent's transcript (keeping its leading system message), then calls `continueRun()`.
- **Stop:** `Agent.abort()`. It also declines a pending file-change request.

## File changes

- When "Ask Before Changing Files" is on, `beforeToolCall` blocks `write` and `edit` calls until the user answers a centered alert (`FileChangeRequest`).
- Requests from parallel calls queue one at a time.
- A declined change returns an error result telling the model the user declined.

## Workspace

- The app's Documents folder. `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` make it visible in Files under On My iPhone → stupid agent.
- On first launch the app writes `Welcome.md`, so the folder appears in Files and the agent has something to read.
- swift pi's `Workspace` rejects paths outside the folder.
- Conversations are stored outside the workspace, in Application Support/Conversations: one JSON file per conversation plus `index.json`. Dates use JSONEncoder's default encoding, because ISO 8601 dropped fractional seconds and saved conversations didn't read back equal.

## Settings

- `ModelSettings` is stored in user defaults. The API key goes in the Keychain (`net.stupidtech.StupidAgent`, account `apiKey`, after first unlock, this device only).
- **Simulator exception:** stupid-app ad-hoc signs simulator builds without Keychain access, so Keychain writes fail with -34018 (`errSecMissingEntitlement`). Under `targetEnvironment(simulator)` the key is stored in user defaults. Device builds only use the Keychain.
- **Save order:** the key is stored before the settings, so a failed key write changes nothing.
- **Keys:** OpenAI, OpenRouter, Groq and DeepSeek need one; Ollama, LM Studio and Custom don't.
- **OpenRouter:** requests carry `HTTP-Referer` and `X-Title` so OpenRouter shows the app's name.
- **Local servers:** ATS allows local networking (`NSAllowsLocalNetworking`), with a local network usage description, for models on a computer on the same network.
- **Form loading:** the settings form loads the saved settings once. `onAppear` runs again when the model picker pops back and used to discard edits. The provider picker sets the base URL through its binding only when the user picks; an `onChange` used to also fire while the saved settings loaded.

## Chat screen

- The chat is stupid chatkit's (`NetworkChatView` driven by `AdapterChatViewModel`), through `AgentChatAdapter`.
- **Mapping:** `chatEntries(...)` turns the transcript into entries, and the adapter maps them to `ChatMessage`s:
  - a user message is an own bubble
  - each agent response is one Markdown bubble, with its thinking ("Thought") and tool calls as `.message` embeds; a tool call's embed shows its title (`Read notes.md`, `· Failed`, `· Stopped`) over its output
  - an error is a notice bubble from the agent with a Retry button (`ChatButtonPressing`); the kit draws system-sender notices as captions without buttons
  - "Stopped" is a system caption
- **Updates:** the adapter is `ChatLiveUpdating`. It observes the session with `withObservationTracking` and calls `onChange`; there is no polling.
- **Typing:** while the agent works and nothing of its reply shows yet, it appears as typing (`ChatTyping`).
- **Sending:** `send` hands the text to the session and returns nil. The session shows the message as sending (`queued`) until the agent takes it in: at once for a new prompt, after the current tool calls for one that steers a run. A message sent after the agent last checked for steering starts the next run when the current one ends.
- **Toolbar:** the screen adds Stop while the agent works, and alerts for file changes and failed sends.
- **Kit settings:** the kit's `ChatKit` launch settings (network icon, events) are left at their defaults.

## Verified

- `swift test`: core tests, including end-to-end sessions with a scripted provider and real file tools (write, and approval denial).
- On an iOS 27 simulator against a local mock OpenAI-compatible server:
  - the settings flow, including loading and picking a model
  - the chatkit screen: a tool call (`ls`) and its answer
  - the file-change alert: a write after Allow, and a declined write shown as Failed
  - a failed request ("Could not connect to the server.") with Retry, retried after the server came back
