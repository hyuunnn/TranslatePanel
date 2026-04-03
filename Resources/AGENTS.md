<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-04 | Updated: 2026-04-04 -->

# Resources

## Purpose
Localization string files for Korean and English. These are processed as SPM resources and loaded at runtime via the `L()` helper in `Sources/Localization.swift`.

## Key Files

| File | Description |
|------|-------------|
| `en.lproj/Localizable.strings` | English UI strings (39 keys) |
| `ko.lproj/Localizable.strings` | Korean UI strings (39 keys) — default localization |

## For AI Agents

### Working In This Directory
- When adding or removing a UI string, **both** `.lproj` files must be updated simultaneously to keep them in sync.
- Keys follow a dot-separated namespace convention: `section.item` (e.g., `settings.title`, `error.ocrFail`, `action.translate`).
- The format is Apple `.strings` file syntax: `"key" = "value";` — every line must end with a semicolon.
- Some strings use `%@` format specifiers (e.g., `error.capture`).
- Korean (`ko`) is the default/development localization as set in `Package.swift`.

### Testing Requirements
- After modifying strings, build the app and verify the UI displays correctly in both languages.
- Switch macOS system language to test each localization.
- Ensure no keys are missing in either file — mismatched keys will show the raw key string at runtime.

### String Key Namespaces

| Prefix | Usage |
|--------|-------|
| `menu.*` | Menu bar items |
| `toolbar.*` | Toolbar buttons |
| `action.*` | Quick action buttons |
| `empty.*` | Empty state guidance |
| `input.*` | Input area |
| `settings.*` | Settings view |
| `error.*` | Error messages |
| `drop.*` | Drag-and-drop overlay |

## Dependencies

### Internal
- Consumed by `Sources/Localization.swift` via `NSLocalizedString` + bundle lookup

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
