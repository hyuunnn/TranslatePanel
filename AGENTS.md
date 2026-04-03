# AGENTS.md

## Project Overview

PreviewLLM — macOS menu-bar/floating-panel app for translation, summarization, and explanation using LLM CLI tools (Claude, Codex). Uses ScreenCaptureKit, Vision, Accessibility API for screen capture and OCR. No API key needed — reuses the user's existing CLI authentication.

- **Stack**: Swift, SwiftUI, Swift Package Manager (`Package.swift`)
- **Layout**: `path: "."` with `sources: ["Sources"]` and `resources: [process("Resources")]`
- **Localization**: Korean (`ko.lproj`) and English (`en.lproj`) — always update both

## Build & Verify

```bash
swift build -c release          # Build check
bash build.sh                   # Full .app bundle (builds, copies resources, signs)
open build/PreviewLLM.app       # Run
```

No test suite — validate by building and running manually.

## Boundaries

### Always
- Run `swift build -c release` after any code change before marking work done
- Update **both** `Resources/en.lproj/Localizable.strings` and `Resources/ko.lproj/Localizable.strings` when adding/changing localization keys
- Verify CLI flags from `--help` output **and** official documentation website — `--help` may not list all features (e.g. env vars, config files)

### Never
- Guess or infer CLI flags — always verify from actual help output or docs
- Write code for a new LLM provider before testing the CLI commands manually

## Adding a New LLM Provider

Currently supported:
- **Claude** — `claude -p --no-session-persistence --model <name> --system-prompt <text>`
- **Codex** — `codex exec --skip-git-repo-check --ephemeral -m <name>` (system prompt prepended to prompt)

### Steps

1. **Research** (complete ALL sub-items before proceeding to Test):
   - [ ] Run `which <cli>` and `<cli> --help`
   - [ ] **MANDATORY**: WebFetch the official documentation website (e.g. `<cli-name>cli.com/docs`, GitHub README). `--help` output is incomplete — always check docs for: env vars, config files, system prompt flags, session management. **Do not skip this step.**
   - [ ] Report findings to user: non-interactive mode, model flag, system prompt mechanism, session persistence opt-out
2. **Test** — Execute actual commands to verify stdin input, stdout output, model flag, and system prompt delivery all work correctly.
3. **Implement** — Create a struct conforming to `LLMProvider` in `Sources/LLMProvider.swift`:
   - Set `id`, `displayName`, `avatarLetter`, `avatarColor`, `defaultModel`, `binaryName`
   - Implement `buildArguments()` — non-interactive flag, output format, model flag
   - Implement `formatPrompt()` — return prompt as-is if system prompt is handled elsewhere (CLI flag, env var, etc.); prepend to prompt if not
   - If the CLI requires env vars (e.g. system prompt via env var), extend the `LLMProvider` protocol or `ChatViewModel.runLLM()` as needed
   - Register the new provider in `LLMProviderRegistry.all`
4. **Localization** — Add `settings.modelPlaceholder.<id>` key to **both** `.strings` files
5. **Documentation** — Update the "Currently supported" list above
6. **Verify** — `swift build -c release`

## Key Files

| File | Purpose |
|------|---------|
| `Sources/PreviewLLMApp.swift` | `@main` entry, `AppDelegate`, menu bar, hotkey routing, ScreenCaptureKit OCR |
| `Sources/ChatView.swift` | SwiftUI chat UI, quick actions, text input, image drag-and-drop |
| `Sources/LLMProvider.swift` | `LLMProvider` protocol, concrete providers, `LLMProviderRegistry` |
| `Sources/ChatViewModel.swift` | ViewModel: clipboard, LLM subprocess, streaming response, Vision OCR |
| `Sources/FloatingPanel.swift` | `NSPanel` subclass (always-on-top), `PanelController` |
| `Sources/HotkeyManager.swift` | Carbon `EventHotKey` for global shortcuts |
| `Sources/RegionCaptureView.swift` | Full-screen overlay for drag-to-select region capture |
| `Sources/SettingsView.swift` | Settings: provider picker, permissions, model input, system prompt |
| `Sources/Localization.swift` | `L()` helper for `NSLocalizedString` |
