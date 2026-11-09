# stupid agent

An agent that runs on your iPhone with your own model. Point it at any OpenAI-compatible server (OpenAI, OpenRouter, Groq, DeepSeek, or Ollama and LM Studio on your computer), and it reads, writes, edits and searches files in its workspace folder, which you also see in the Files app. Tool calls run on the phone.

Built on [stupid pi](https://github.com/stephancill/stupid-pi), a Swift port of [pi](https://github.com/earendil-works/pi).

## Build

Requires the `stupid-app` CLI.

```sh
swift test                  # core tests
stupid-app run --simulator  # build, install and launch
```

To update stupid pi: `scripts/vendor-stupid-pi.sh <tag>`.
