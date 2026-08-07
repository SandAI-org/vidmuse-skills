# VidMuse Agent Command Map

Assume the `vidmuse` command runtime is available on `PATH` after following `SKILL.md`.

## Local Preview

| Task | Command |
|---|---|
| Preview the default `dsl.json` | `vidmuse serve` |
| Preview a specific DSL file | `vidmuse serve ./project.dsl.json` |
| Select a local preview port | `vidmuse serve ./project.dsl.json --port 5175` |
| Explicitly listen on another interface | `vidmuse serve ./project.dsl.json --host 0.0.0.0` |
| Prevent editing the DSL from the preview | `vidmuse serve ./project.dsl.json --read-only` |

The server listens on `127.0.0.1` by default. A non-loopback `--host` is an explicit trust decision: the local preview has no mandatory authentication and intentionally permits project-local paths and HTTP(S) media targets. Video thumbnails use `ffmpeg` from `PATH`; set `FFMPEG_BIN` for a nonstandard location. The released CLI binary does not require Go at runtime.

## Local Render

| Task | Command |
|---|---|
| Render the complete video | `vidmuse render ./project.dsl.json` |
| Render a transparent overlay | `vidmuse render ./project.dsl.json --mode overlay` |

`vidmuse render` requires Node.js 22+ and FFmpeg. Check `node --version` and `ffmpeg -version` first. Without `HYPERFRAMES_BIN`, its first HyperFrames render also needs npm network access to download the pinned renderer.

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
| Filter by model name prefix | `vidmuse model list --model kling` |
| Search display name or model name | `vidmuse model list --search pro` |
| Run image model | `vidmuse model run --param '{"model_name":"<modelName>","prompt":"A sunrise"}'` |
| Run video with reference images | `vidmuse model run --param '{"model_name":"<modelName>","prompt":"Camera pushes in","elements":[{"reference_image_urls":["https://cdn.example.org/reference.png"]}]}'` |
| Run video with a frontal image | `vidmuse model run --param '{"model_name":"<modelName>","prompt":"Animate the character","elements":[{"frontal_image_url":"https://cdn.example.org/character.png"}]}'` |
| Run video with a reference video | `vidmuse model run --param '{"model_name":"<modelName>","prompt":"Follow this motion","elements":[{"video_url":"https://cdn.example.org/reference.mp4"}]}'` |
| Run video with audio | `vidmuse model run --param '{"model_name":"<modelName>","prompt":"Avatar speaking","audios":[{"url":"https://cdn.example.org/voice.wav"}]}'` |
| Run audio model | `vidmuse model run --param '{"model_name":"<modelName>","prompt":"Warm cinematic music"}'` |
| Run subtitle alignment | `vidmuse model run --param '{"model_name":"doubao_speech/audio_text_alignment","prompt":"subtitle transcript","files":["/users/42/audio.wav"]}'` |
| Submit a media model asynchronously | `vidmuse model run --async --param '{"model_name":"<modelName>","prompt":"A sunrise"}'` |
| Query an asynchronous task result | `vidmuse model result <taskId>` |
| Analyze music | `vidmuse tool run analyze_music --param '{"audio_path":"./music.mp3"}'` |

Notes:
- Type filter flags are mutually exclusive.
- `--model` filters by the Manager model configuration name prefix, not by the provider model path.
- `--search` performs fuzzy matching against display names and model names.
- `model run` requires `--param`; the value must be a JSON object containing `model_name`. Image, audio, and video models also accept `--async`.
- `--param` is the complete Aion Manager request. Use canonical snake_case fields and model-specific nested structures directly.
- Public media URLs pass through unchanged. Local paths in `files`, image URL fields, audio URL fields, and video element fields are uploaded before the request. ATA `files[]` entries use the returned `savedPath`; other media inputs use the returned `downloadUrl`.
- The CLI does not infer or remap `prompt`, `elements`, or `generation_type`.
- cli-server resolves the enabled model configuration from `model_name` and infers whether the request is video, image, audio, or ATA text.
- Each video `elements` entry must follow the Aion schema and select its own supported reference mode, such as `reference_image_urls`, `frontal_image_url`, or `video_url`.
- Aion ATA returns raw JSON and does not generate or register SRT text assets.
- By default, `model run` waits for cli-server to receive the terminal Aion result. With `--async`, supported media models print only the task ID; `model result <taskId>` performs one task query and prints the result after the task succeeds. It does not wait in cli-server, so retry it later while the task is still in progress. Text models do not support `--async`.
- The CLI does not expose generic tool models or general-purpose text models. `analyze_music` is the only dedicated tool command and does not require a thread.
- `analyze_music` accepts a local audio/video path or public HTTP(S) URL. Public media is downloaded to a temporary CLI file, uploaded through the model input flow, and forwarded to VidMCP as the returned `savedPath`.

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
- `voiceId` is the canonical voice-library ID, such as `F-EN-001`.
- When a TTS request requires a provider-specific ID, use `modelIds[<model-name>]`, such as `modelIds["minimax/speech-2.6-hd"]`.
- For voice models that support cloning, use `sampleAudioUrl` as the reference audio when the model contract accepts reference audio.

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
- File-type flags: `--image`, `--video`, and `--music`.
- Source flags: `--uploaded` and `--generated`.
- Favorite filter: `--favorite[=true|false]`.
- `--all-threads` cannot be used with `--thread`.
- `generation-params` requires both `--thread` and `--file-path`.

## Threads And Messages

| Task | Command |
|---|---|
| Create a free canvas | `vidmuse thread create --canvas` |
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
- `thread create` and `message send` support repeated `--file` and `--file-url` flags.
- `thread create --canvas` creates an empty free canvas using the `adventurer` thread type.
- `thread create --options` accepts JSON and merges it with explicitly provided option flags.
- `--default-model key=value` is repeatable and supplies default model options consistent with the frontend.
- When no thread ID is provided, `message list`, `message send`, and `thread status` use the configured default thread.

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
