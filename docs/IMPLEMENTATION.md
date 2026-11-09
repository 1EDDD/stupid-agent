# Implementation notes

## Agent core

- **Source:** swift pi, a package dependency pinned in `Package.resolved`. It was vendored while stupid-app built only local sources; stupid-app 0.0.27 resolves package dependencies.
- **Session:** `AgentSession` owns one swift pi `Agent`:
  - its system prompt is `systemPrompt(workspaceName:)`
  - its tools are `fileTools(workspace:)`
  - its transcript is the conversation's
- **Messages:** the agent's event stream is the only source of `AgentSession.messages`. The run finishes, and the conversation is saved, when the `agentEnd` event is handled. An earlier version replaced `messages` with the agent's state after `prompt()` returned. Events still queued then were appended again, which duplicated replies.
- **Title:** a new conversation takes its title from the first message as soon as it is sent, not when the run ends.
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

## Other apps' containers

- **Off by default:** Settings → Workspace → "Access Other Apps" (`ModelSettings.allowOtherApps`). When on, the agent's tools are swift pi's file tools plus `apps`; when off, the tool set is exactly the workspace tools. `AgentSession.update` sets the new tools, so the switch applies to open conversations.
- **Reach:** `SandboxBridge` is a clean-room implementation of the worse_query technique: it replaces the App Group's `Library/Caches` with a symlink to a target, asks containermanagerd for a sandbox token through `container_query_*`, and consumes it with `sandbox_extension_consume`. The grant lasts for the process.
- **Prerequisites:** the App Group `group.net.stupidtech.StupidAgent` in `App.entitlements` and `stupid-app.yml` (`APP_GROUPS`), associated with the bundle ID in the Developer Portal. The association is a manual portal step, so a profile made before it doesn't authorize the entitlement and `signing setup` has to be rerun after it.
- **Platforms:** iOS 26 and 27 on a real device. Simulator builds report the feature unavailable, because containermanager there is the host's.
- **Paths:** `/apps/<bundle id>/…` for app data containers and `/app-groups/<group id>/…` for App Groups. `apps` lists them. A container path is resolved and granted, then the same swift pi tool runs with the container as its `Workspace`, so workspace containment is unchanged and file-tool behavior is identical.
- **SQLite:** the `sqlite` tool reads a database from the workspace or a container. It opens read-only (with an `immutable=1` fallback for a WAL database whose sidecars can't be opened), sets `PRAGMA query_only`, rejects non-read-only statements and multiple statements, and stops runaway queries with a progress-handler step budget. Results are JSON rows with a row limit and a 64KB cap; blobs are described, not returned.
- **Discovery:** `SandboxContainers` lists `/var/mobile/Containers/Data/Application` and `/var/mobile/Containers/Shared/AppGroup` when a parent grant works (App Groups on iOS 27); otherwise it resolves inodes to paths with `fsgetpath`, bounded by the inode of a freshly created file, and reads `com.apple.containermanager.identifier` from each candidate. Containers are cached for the process.
- **Approvals:** writes still go through "Ask Before Changing Files", and the alert says the file is in another app's container.
- **Shared container:** every grant removes the App Group's `Library/Caches` and leaves it empty, so that group is reserved for this feature.
- **Distribution:** private API and a sandbox escape. This can't ship on the App Store.


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
  - each agent response is one Markdown bubble, with its thinking ("Thought") and tool calls as `.message` embeds; a tool call's embed shows its title (`Read notes.md`, `· Failed`, `· Stopped`) over its output. `ls` of the workspace root reads "List", not "List ."
  - a response with both thinking and text puts the thinking in a bubble of its own ahead of the text, since the kit draws embeds after a bubble's text and the model thought first
  - an error is a notice bubble from the agent with a Retry button (`ChatButtonPressing`); the kit draws system-sender notices as captions without buttons
  - "Stopped" is a system caption
- **Updates:** the adapter is `ChatLiveUpdating`. It observes the session with `withObservationTracking` and calls `onChange`; there is no polling.
- **Typing:** while the agent works and nothing of its reply shows yet, it appears as typing (`ChatTyping`).
- **Sending:** `send` hands the text to the session and returns nil. The session shows the message as sending (`queued`) until the agent takes it in: at once for a new prompt, after the current tool calls for one that steers a run. A message sent after the agent last checked for steering starts the next run when the current one ends.
- **Model menu:** the adapter adopts chatkit's `ChatComposerMenus`. A brain icon at the end of the composer's text row opens a menu headed by the current model id, with the recent models (`ModelSettings.recentModelIds`, up to six, most recent first, checkmark on the current) and "Choose Model…". That opens `ModelPickerView`: the server's `GET /models`, searchable, and any typed id ("Use …"). Choosing switches the app-wide model (`AppModel.selectModel`), the same setting Settings changes, so every conversation uses it from its next request. Switching keeps the model being left in the recents, including one set before recents were kept. Settings saved before `recentModelIds` existed decode with defaults (`ModelSettings.init(from:)`).
- **Toolbar:** the screen adds Stop while the agent works, and alerts for file changes and failed sends.
- **Kit settings:** the kit's `ChatKit` launch settings (network icon, events) are left at their defaults.

## Verified

- `swift test`: core tests, including end-to-end sessions with a scripted provider and real file tools (write, and approval denial).
- On an iOS 27 simulator against a local mock OpenAI-compatible server:
  - the settings flow, including loading and picking a model
  - the chatkit screen: a tool call (`ls`) and its answer
  - the file-change alert: a write after Allow, and a declined write shown as Failed
  - a failed request ("Could not connect to the server.") with Retry, retried after the server came back
- On the same simulator against OpenRouter (`openrouter/free`): list, read and write with a real model, the file-change alert, and streamed reasoning.
