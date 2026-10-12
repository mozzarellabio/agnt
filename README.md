# agnt

AI coding agent for the terminal. Runs teams of agents in parallel on any model. One binary for Linux and Windows. Free.

Not to be confused with agnt-gg/agnt, an unrelated agent operating system.

## Install

Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/mozzarellabio/agnt/main/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/mozzarellabio/agnt/main/install.ps1 | iex
```

## Features

- Parallel agent teams (`/team`, `/spawn`, `/orch`) with a shared task board
- Anthropic, OpenAI, OpenRouter, Gemini, DeepSeek, Groq, xAI, Mistral, Ollama, LM Studio and any OpenAI-compatible endpoint
- Batched tool calls, parallel reads, prompt caching, context compaction
- Diagnostics after every edit, typecheck and tests before finishing
- Modes: ask, auto, plan, free
- Undo, rewind, git worktrees
- Git and GitHub: `/commit`, `/pr`, `/issue`, `/checks`
- MCP servers, plugins, skills, scheduled prompts
- Remote control from a phone via QR code

## Links

- Site: https://mozzarellabio.github.io/agnt/
- Docs: https://mozzarellabio.github.io/agnt/docs.html
- Local models: https://mozzarellabio.github.io/agnt/ollama.html
- Changelog: https://mozzarellabio.github.io/agnt/changelog.html
