# Plan

## Goal

An agent that runs on the iPhone with the user's own model. The model can be any server speaking the OpenAI Chat
Completions API: a hosted provider with the user's key, or a model on their own computer. Tool calls execute on the
device. The tool set grows over time.

## Now

- Bring your own model:
  - provider presets (OpenAI, OpenRouter, Groq, DeepSeek, Ollama, LM Studio) or a custom base URL
  - an API key, stored in the Keychain
  - a model id, which can be picked from the server's model list
  - reasoning level and image input
- File tools on the app's workspace folder: read, write, edit, ls, find, grep. The workspace is visible in the Files app.
- The agent asks before it creates or changes a file (setting, on by default).
- Conversations: list, new, delete, persisted on the device. Messages sent while the agent works steer it. Stop and retry.

## Next

- Move the chat screen to stupid chatkit (the chat framework being extracted from stupid social) once it is published.
- More tools, each running in the app sandbox:
  - fetch a URL
  - web search through a configured service
  - calendar, reminders and contacts with permission
  - photos as input
  - Shortcuts
- Attach images and files to messages.
- Remote MCP servers over HTTP.
- Compaction for long conversations.
- More provider APIs in swift pi (Anthropic Messages, OpenAI Responses).
- Usage and error reporting through stupid metrics.
