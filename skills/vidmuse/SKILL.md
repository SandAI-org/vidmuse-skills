---
name: vidmuse
description: Use when an AI agent needs to work with VidMuse projects, account state, subscription credits, video/audio/image/text/tool models, generated or uploaded assets, style library entries, voice library entries, generation parameters, threads, messages, or long-term memory. Installs and uses the `vidmuse` command runtime when needed.
---

# VidMuse Skill

Use this skill when a task asks for VidMuse account state, subscription plan, model discovery, assets, style library entries, voice library entries, generation params, thread/message operations, or long-term memory operations. Treat the `vidmuse` command as the runtime for accessing VidMuse capabilities; keep user-facing answers focused on the VidMuse task unless the user asks about the command itself.

## Workflow

1. Ensure the `vidmuse` command runtime exists.

   macOS, Linux, WSL, or Git Bash:

   ```bash
   if vidmuse_path="$(command -v vidmuse)"; then
     :
   else
     tmp="$(mktemp)"
     curl -fsSL "https://vidmuse.sandcdn.com/cli/install.sh" -o "$tmp"
     installed_path="$(VIDMUSE_CLI_VERSION="${VIDMUSE_CLI_VERSION:-latest}" bash "$tmp" | tail -n 1)"
     installed_dir="$(dirname "$installed_path")"
     case ":${PATH:-}:" in *":${installed_dir}:"*) ;; *) export PATH="${installed_dir}:${PATH:-}" ;; esac
   fi
   vidmuse --version
   ```

   Windows PowerShell:

   ```powershell
   if (-not (Get-Command vidmuse -ErrorAction SilentlyContinue)) {
       $tmp = Join-Path $env:TEMP "install-vidmuse.ps1"
       Invoke-WebRequest "https://vidmuse.sandcdn.com/cli/install.ps1" -OutFile $tmp -UseBasicParsing
       $installedPath = (& powershell -ExecutionPolicy Bypass -File $tmp | Select-Object -Last 1)
       $installedDir = Split-Path -Parent $installedPath
       if (($env:PATH -split [System.IO.Path]::PathSeparator) -notcontains $installedDir) {
           $env:PATH = "$installedDir$([System.IO.Path]::PathSeparator)$env:PATH"
       }
   }
   vidmuse --version
   ```

2. Authenticate when needed.

   First check whether the current session is already authenticated:

   ```bash
   vidmuse profile get --output json
   ```

   If the command returns an auth error, ask before starting any login flow because browser and device login require user action.

   Use this decision tree:

   | Environment | Command |
   |---|---|
   | Local desktop with browser access | `vidmuse login` |
   | Headless or remote terminal with streaming output | `vidmuse login --device` |
   | Agent shell cannot keep a long-running command visible | `vidmuse login --device --start`, show the URL/code to the user, then run `vidmuse login --device --complete` after the user confirms authorization |

3. For command routing, read `references/command-map.md`.

## Output Contract

Default output mode is `text`. Add `--output json` only when structured parsing is needed.

Use `text` for compact plain-language responses. Nested lists and maps are rendered as indented blocks.

Use `table` only for short human-facing summaries because top-level structs, maps, lists, and lists of maps are rendered as tables when possible, while nested lists and maps stay compact inside table cells.

Paginated text/table output uses a human summary such as:

```text
Showing 1-20 of 88
```

JSON output preserves structured fields such as `limit`, `offset`, `total`, and `data` when the API returns them.

Streams:

| Stream | Meaning |
|---|---|
| stdout | Command result in the selected output mode |
| stderr | Errors, verbose HTTP logs, installation logs |

Exit codes:

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | General error |
| 2 | Usage or validation error |
| 3 | Auth error: missing, expired, or invalid auth |
| 4 | Network or API error |

Error handling:

1. Check the exit code first.
2. If exit code is `0`, parse stdout only when `json` mode was requested.
3. If exit code is non-zero, show a concise error based on stderr.
4. For exit code `3`, ask the user to run `vidmuse login` or `vidmuse login --device`.
5. For exit code `4`, mention the network or API failure and retry only when the operation is read-only or explicitly safe to repeat.

## Safety

Read-only commands may be run directly when the user asks for information. Mutating commands such as `thread create`, `message send`, `memory create`, `memory update`, `memory append`, `memory push`, and `memory pop` require explicit user intent.

Never print auth tokens, cookies, or full config files in the final answer because final answers can be saved to transcripts, shared as screenshots, or copied into bug reports.
