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
- Verify CLI flags from `--help` output first — if `--help` is incomplete (e.g. missing env vars, config files, system prompt), check official documentation

### Never
- Guess or infer CLI flags — always verify from actual help output
- Write code for a new LLM provider before testing the CLI commands manually

### Known failure mode — DO NOT REPEAT
> Agent skipped docs for `claude` CLI → missed `--system-prompt` (docs-only, not in `--help`) → broken implementation, had to redo. When `--help` is incomplete, check official docs.

## Adding a New LLM Provider

Supported providers are defined in `Sources/LLMProvider.swift` → `LLMProviderRegistry.all`.

### Steps

1. **Research** (complete ALL sub-items before proceeding to Test):
   - [ ] Run `which <cli>` and `<cli> --help`
   - [ ] If `--help` is incomplete, check official documentation for: env vars, config files, system prompt flags, session management
     - For large pages (GitHub README, 400KB+), use `curl -sL <raw-url> | grep -iC15 "<keyword>"` instead of WebFetch to avoid context bloat
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
