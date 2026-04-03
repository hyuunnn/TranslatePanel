# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PreviewLLM is a macOS menu-bar/floating-panel app that provides translation, summarization, and explanation features using LLM CLI tools (Claude, Codex, and extensible to others). It uses macOS native frameworks (ScreenCaptureKit, Vision, Accessibility API) for screen capture and OCR. No separate API key needed — it reuses the user's existing CLI authentication.

## Build & Development Commands

```bash
# Build release .app bundle
bash build.sh

# Run the built app
open build/PreviewLLM.app

# Install to Applications
cp -r build/PreviewLLM.app /Applications/

# SwiftPM build (intermediate step, usually called via build.sh)
swift build -c release
```

There is no test suite — the app is validated by building and running manually. The build script handles creating the `.app` bundle structure, copying resources, generating `Info.plist`, and code-signing.

## Architecture

This is a Swift/macOS SwiftUI app managed via Swift Package Manager (`Package.swift`). The target uses an unusual layout — `path: "."` with `sources: ["Sources"]` and `resources: [process("Resources")]`.

### File Structure

| File | Purpose |
|------|---------|
| `Sources/PreviewLLMApp.swift` | `@main` entry point, `AppDelegate`, menu bar setup, hotkey action routing, ScreenCaptureKit OCR pipeline |
| `Sources/ChatView.swift` | SwiftUI chat UI with toolbar, quick actions, messages list, text input, image drag-and-drop |
| `Sources/LLMProvider.swift` | `LLMProvider` protocol, concrete providers (Claude, Codex), and `LLMProviderRegistry` for extensible multi-CLI support |
| `Sources/ChatViewModel.swift` | `@MainActor` ViewModel: clipboard handling, LLM CLI subprocess management, streaming response handling, Vision OCR for dropped images |
| `Sources/FloatingPanel.swift` | Custom `NSPanel` subclass (always-on-top, non-activating) and `PanelController` for show/hide |
| `Sources/HotkeyManager.swift` | Carbon `EventHotKey` registration for global shortcuts |
| `Sources/RegionCaptureView.swift` | Full-screen overlay window with crosshair cursor for region selection (drag-to-select rectangle) |
| `Sources/SettingsView.swift` | Settings sheet: provider picker, permissions status, model input, system prompt editor, hotkey reference |
| `Sources/Localization.swift` | `L()` helper wrapping `NSLocalizedString` with custom bundle resolution |
| `Resources/en.lproj/` / `Resources/ko.lproj/` | `.strings` files for Korean/English localization |

### Key Flows

1. **Toggle Panel** (`⌘⇧\`) — Show/hide `FloatingPanel` via `PanelController`
2. **Select Translate** (`⌘⇧,`) — Uses Accessibility API (`AXUIElement`) to get selected text from focused element, copies to pasteboard, triggers translation via notification
3. **Capture Translate** (`⌘⇧.`) — Uses `SCShareableContent` + `SCScreenshotManager` to capture full screen (excluding app's own windows), runs Vision `VNRecognizeTextRequest` OCR, then sends extracted text to the selected LLM for translation
4. **Region Capture Translate** (`⌘⇧'`) — Shows a full-screen overlay (`RegionCaptureWindow`), user drags to select rectangle, then captures only that region via ScreenCaptureKit with `sourceRect`
5. **Image Drop** — Drag image onto panel → Vision OCR → translation
6. **Free-text chat** — Type in input, send to selected LLM CLI subprocess with streaming output

### LLM CLI Integration

The app supports multiple LLM CLI tools via the `LLMProvider` protocol (`Sources/LLMProvider.swift`). Each provider defines its binary name, argument format, and system prompt handling.

**Currently supported providers:**
- **Claude** — `claude -p --no-session-persistence --model <name> --system-prompt <text>`
- **Codex** — `codex exec --skip-git-repo-check --ephemeral -m <name>` (no system prompt flag; prepended to prompt)

`ChatViewModel.runLLM()` spawns a `Process` using the selected provider. Key details:
- Binary path is resolved per provider via `resolveShell(for:)` (runs `which <binary>` via `zsh -li`, cached per binary name)
- Provider is captured once per request to ensure consistency across `appendMessages` and `runLLM`
- Arguments are built by `provider.buildArguments()`, prompt is formatted by `provider.formatPrompt()`
- Prompt is piped to stdin, streaming stdout is read and appended to the assistant message

**Adding a new provider:**
1. **Research** — Run `which <cli>` and `<cli> --help` to identify the non-interactive mode, model flag, system prompt flag, and session persistence opt-out. Do NOT guess or infer flags — always verify from actual help output.
2. **Test** — Execute actual commands to verify stdin input, stdout output, and model flag work correctly. Do NOT write code until tests pass.
3. **Implement** — Create a struct conforming to `LLMProvider` in `Sources/LLMProvider.swift`, register it in `LLMProviderRegistry.all`, and add a `settings.modelPlaceholder.<id>` localization key.
4. **Verify** — Run `swift build -c release` to confirm the build succeeds.

### Messaging Between Components

`AppDelegate` and `ChatViewModel` communicate via `NotificationCenter`:

- `.translateClipboard` — Triggers clipboard text translation (posted by `Select Translate` hotkey handler and `handleOCRResult`)
- `.ocrError` — Displays OCR errors in UI (posted on `captureScreenAndOCR` failure)

### Persistence

Settings are stored via `@AppStorage` / `UserDefaults`:
- `llmProvider` — selected provider id (default: `"claude"`)
- `claudeModel` / `codexModel` — per-provider model name (defaults: `"sonnet"` / `"gpt-5.4-mini"`)
- `systemPrompt` — custom system prompt
- `sourceLang` / `targetLang` — translation language codes

### Permissions

- **Screen Recording** — required for `⌘⇧.` and `⌘⇧'` capture features (ScreenCaptureKit)
- **Accessibility** — required for `⌘⇧,` select translate (Accessibility API to read selected text)
- Permissions are requested/checked in `SettingsView`
