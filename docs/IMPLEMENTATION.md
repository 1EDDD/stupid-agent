# Implementation notes

## Agent core

- **Source:** stupid pi, vendored into `Vendor/StupidPi` at a tag by `scripts/vendor-stupid-pi.sh`. The tag and commit are in `Vendor/StupidPi/VERSION`. stupid-app builds only local sources, so the package isn't resolved by SwiftPM.
- **Session:** `AgentSession` owns one stupid pi `Agent`:
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
- stupid pi's `Workspace` rejects paths outside the folder.
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

- `ChatView` is a plain SwiftUI list built from `chatItems(...)`: user bubbles, assistant text (inline Markdown), thinking and tool calls as disclosure rows, and errors.
- It is a placeholder for stupid chatkit, which is being extracted from stupid social separately. `ChatItem` is the boundary that an adapter will map.

## Verified

- `swift test`: core tests, including end-to-end sessions with a scripted provider and real file tools (write, and approval denial).
- On an iOS 27 simulator against a local mock OpenAI-compatible server:
  - the settings flow, including loading and picking a model
  - a tool call (`ls`) and its answer
  - the file-change alert, and a write after Allow
