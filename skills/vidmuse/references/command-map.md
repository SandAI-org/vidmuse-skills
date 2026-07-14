# VidMuse Agent Command Map

Assume the `vidmuse` command runtime is available on `PATH` after following `SKILL.md`.

## Account

| Task | Command |
|---|---|
| Get current profile | `vidmuse profile get` |
| Get subscription plan and credits | `vidmuse plan get` |
| Interactive browser login | `vidmuse login` |
| Headless/device login | `vidmuse login --device` |
| Start non-blocking device login | `vidmuse login --device --start` |
| Complete pending device login | `vidmuse login --device --complete` |
| Logout and clear local session | `vidmuse logout` |

## Models

| Task | Command |
|---|---|
| List all models | `vidmuse model list` |
| List video models | `vidmuse model list --video` |
| List audio models | `vidmuse model list --audio` |
| List image models | `vidmuse model list --image` |
| List text models | `vidmuse model list --text` |
| List tool models | `vidmuse model list --tool` |
| Filter by model name prefix | `vidmuse model list --model kling` |
| Search display name or model name | `vidmuse model list --search pro` |

Notes:
- Type flags are mutually exclusive.
- `--model` filters by manager model config name prefix, not provider model path.
- `--search` fuzzy-matches display name and model name.

## Styles

| Task | Command |
|---|---|
| List styles | `vidmuse style list` |
| List official and personal styles | `vidmuse style list --scope all` |
| List official styles | `vidmuse style list --scope official` |
| List personal styles | `vidmuse style list --scope user` |
| List style summaries | `vidmuse style list --scope official --limit 12 --view summary -o json` |
| Get style details | `vidmuse style get <styleId> --view full -o json` |
| Project style fields | `vidmuse style list --scope official --fields id,name,description,tags,imageUrl -o json` |
| Filter styles by tag | `vidmuse style list --tag "Dreamcore Style"` |
| Require multiple tags | `vidmuse style list --tag "Dreamcore Style" --tag "Lo-fi/VHS Aesthetic"` |
| Paginate styles | `vidmuse style list --limit 20 --offset 0` |

## Voices

| Task | Command |
|---|---|
| List voices | `vidmuse voice list` |
| List voice summaries | `vidmuse voice list --limit 20 --view summary -o json` |
| Filter by language and gender | `vidmuse voice list --language en --gender female -o json` |
| Filter by emotion text | `vidmuse voice list --emotion "calm" -o json` |
| Search voice descriptions | `vidmuse voice search -q "premium brand ad" -o json` |
| Require a model mapping | `vidmuse voice list --model minimax/speech-2.6-hd -o json` |
| Get voice details | `vidmuse voice get F-EN-001 --view full -o json` |
| Project voice fields | `vidmuse voice list --fields voiceId,language,gender,summary,modelIds -o json` |
| Paginate voices | `vidmuse voice list --limit 20 --offset 0` |

Notes:
- `voiceId` is the canonical library ID, for example `F-EN-001`.
- For TTS calls that need a provider-specific ID, use `modelIds[<model-name>]`, for example `modelIds["minimax/speech-2.6-hd"]`.
- For clone-capable voice models, use `sampleAudioUrl` as the reference audio when the model contract accepts reference audio.

## Assets

| Task | Command |
|---|---|
| List assets | `vidmuse asset list` |
| List assets for one thread | `vidmuse asset list --thread <threadId>` |
| List assets across all threads | `vidmuse asset list --all-threads` |
| List generated favorite images | `vidmuse asset list --image --generated --favorite` |
| List uploaded videos | `vidmuse asset list --video --uploaded` |
| List music assets | `vidmuse asset list --music` |
| Paginate assets | `vidmuse asset list --thread <threadId> --limit 20 --offset 0` |
| Get generation params for an asset | `vidmuse asset generation-params --thread <threadId> --file-path <path>` |

Notes:
- File type flags: `--image`, `--video`, `--music`.
- Source flags: `--uploaded`, `--generated`.
- Favorite filter: `--favorite[=true|false]`.
- `--all-threads` cannot be combined with `--thread`.
- `generation-params` requires both `--thread` and `--file-path`.

## Threads And Messages

| Task | Command |
|---|---|
| Create a thread | `vidmuse thread create --text "Create a video"` |
| Create with options | `vidmuse thread create --text "Create a video" --aspect-ratio 16:9 --resolution 720p --file ./input.png` |
| List threads | `vidmuse thread list --limit 20 --offset 0` |
| Get thread status | `vidmuse thread status <threadId>` |
| Save default thread | `vidmuse thread use <threadId>` |
| List messages | `vidmuse message list --thread <threadId> --limit 50` |
| List latest messages | `vidmuse message list --thread <threadId> --last 5` |
| Send message | `vidmuse message send --thread <threadId> --text "Make it shorter"` |
| Send with mentions | `vidmuse message send --thread <threadId> --text "Use @{style}" --mentions '{"style":{"displayName":"Style"}}'` |

Notes:
- `thread create` and `message send` accept repeated `--file` and `--file-url`.
- `thread create --options` accepts JSON merged with explicit option flags.
- `--default-model key=value` can be repeated for frontend-aligned default model options.
- `message list`, `message send`, and `thread status` use the configured default thread when no thread ID is passed.

## Memory

Memory key types are `TEXT`, `LIST`, and `INDEX_DETAIL`.

| Task | Command |
|---|---|
| List memory keys | `vidmuse memory list` |
| Create TEXT key | `vidmuse memory create <name> --text` |
| Create LIST key | `vidmuse memory create <name> --list` |
| Create INDEX_DETAIL key | `vidmuse memory create <name> --index-detail` |
| Get memory content | `vidmuse memory get <name>` |
| Get paginated items | `vidmuse memory get <name> --offset 0 --limit 10` |
| Include index detail | `vidmuse memory get <name> --detail` |
| Replace TEXT content | `vidmuse memory update <name> "<value>"` |
| Update INDEX_DETAIL detail | `vidmuse memory update <name> "<detail>" --item-id <id>` |
| Append to TEXT | `vidmuse memory append <name> "<line>"` |
| Push list item | `vidmuse memory push <name> "<item>"` |
| Push item with detail | `vidmuse memory push <name> "<item>" --detail "<detail>"` |
| Pop latest LIST item | `vidmuse memory pop <name>` |
