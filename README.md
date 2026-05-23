# VidMuse Skills

Public skills and installer entrypoints for AI agents that work with VidMuse.

## VidMuse Skill

The main skill is published at:

```text
skills/vidmuse/SKILL.md
```

Use it when an AI agent needs to create or inspect VidMuse projects, manage threads and messages, inspect assets, discover models, or work with long-term memory.

## Install the VidMuse command runtime

macOS, Linux, WSL, or Git Bash:

```bash
curl -fsSL https://vidmuse.sandcdn.com/cli/install.sh | bash
```

Windows PowerShell:

```powershell
iwr https://vidmuse.sandcdn.com/cli/install.ps1 -UseBasicParsing | iex
```

The same installer scripts are mirrored in this repository root for review and fallback use.
