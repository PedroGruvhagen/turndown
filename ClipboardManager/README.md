# Demoskop Clipboard

A native macOS clipboard history manager with automatic Markdown to Rich Text conversion, built for Demoskop.

## Features

- **Clipboard History**: Automatically saves everything you copy
- **Markdown → Rich Text**: Automatically converts Markdown to formatted rich text
- **Global Hotkeys**: Quick access via customizable keyboard shortcuts
- **Menu Bar App**: Lives in your menu bar, always accessible
- **Favorites**: Star important clipboard items to keep them forever
- **Search**: Quickly find past clipboard entries
- **Export/Import**: Backup and restore your clipboard history

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building from source)
- Apple Developer account (for code signing and distribution)

## Installation

### From Source (Recommended: Swift Package Manager)

1. Clone the repository
2. Navigate to the `ClipboardManager` directory
3. Build with Swift Package Manager:
   ```bash
   cd ClipboardManager
   swift build -c release
   ```
4. Or use the build script:
   ```bash
   ./scripts/build-release.sh
   ```

### From Source (Xcode)

1. Clone the repository
2. Open `ClipboardManager.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run (⌘R)

### For Distribution

See the [Distribution Guide](#distribution) below.

## Usage

### Keyboard Shortcuts (Default)

| Shortcut | Action |
|----------|--------|
| ⇧⌥V | Show clipboard history |
| ⌥⌘V | Paste most recent as rich text |
| ⇧⌥⌘V | Paste most recent as plain text |

All shortcuts are customizable in Preferences.

### Menu Bar

Click the clipboard icon in the menu bar to:
- View clipboard history
- Click any entry to paste it
- Star entries to keep them as favorites
- Search through history
- Access preferences

### Markdown Conversion

When you copy text that contains Markdown formatting, DemoskopClipboard automatically:
1. Detects the Markdown syntax
2. Converts it to rich text (RTF/HTML)
3. Updates the clipboard with both formats

When you paste:
- In rich text editors (Word, Pages, Mail): Pastes formatted text
- In plain text editors (Terminal, code editors): Pastes plain text

## Configuration

### Preferences

Access via the gear icon in the menu bar dropdown or ⌘, (Cmd+Comma).

**General**
- Launch at login
- Auto-convert Markdown to rich text
- Maximum history items (default: 1000)

**Shortcuts**
- Customize all keyboard shortcuts
- Disable individual shortcuts

**Advanced**
- Polling interval (how often to check clipboard)
- Export/Import history
- Database location

## Distribution

### Code Signing & Notarization

1. **Prerequisites**:
   - Apple Developer Program membership ($99/year)
   - Developer ID Application certificate
   - App-specific password for notarization

2. **Build for Distribution**:
   ```bash
   # Using the build script (recommended)
   cd ClipboardManager
   ./scripts/build-release.sh

   # This creates build/DemoskopClipboard.app
   ```

3. **Notarize**:
   ```bash
   xcrun notarytool submit build/export/DemoskopClipboard.app \
                   --apple-id "your@email.com" \
                   --team-id "YOURTEAMID" \
                   --password "@keychain:AC_PASSWORD" \
                   --wait

   xcrun stapler staple build/export/DemoskopClipboard.app
   ```

4. **Create DMG**:
   ```bash
   # Using the DMG script (recommended)
   ./scripts/create-dmg.sh

   # This creates build/DemoskopClipboard-{version}.dmg
   ```

### MDM Distribution

For enterprise deployment via Jamf, Mosyle, or other MDM solutions:
1. Build and notarize the app
2. Create a signed installer package (.pkg)
3. Upload to your MDM solution

## Architecture

```
ClipboardManager/
├── ClipboardManagerApp.swift     # Main app entry point
├── Views/
│   ├── MenuBarView.swift         # Main menu bar UI
│   └── PreferencesView.swift     # Settings UI
├── Services/
│   ├── ClipboardWatcher.swift    # Clipboard monitoring
│   ├── MarkdownConverter.swift   # MD → RTF conversion
│   ├── HotKeyService.swift       # Global shortcuts
│   ├── UpdateService.swift       # Sparkle auto-updates
│   └── LaunchAtLoginService.swift
├── Models/
│   └── ClipboardEntry.swift      # Data model
├── Persistence/
│   ├── PersistenceController.swift  # Core Data setup
│   └── HistoryStore.swift           # History management
└── scripts/
    ├── build-release.sh          # Build .app bundle
    ├── create-dmg.sh             # Create DMG installer
    ├── generate_keys.sh          # Sparkle key generation
    └── sign_update.sh            # Sign updates for Sparkle
```

## Dependencies

- [Down](https://github.com/johnxnguyen/Down) - Markdown parsing (cmark-gfm)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkeys
- [Sparkle](https://github.com/sparkle-project/Sparkle) - Auto-updates

## Privacy & Security

- **No network access**: The app works entirely offline (except for update checks)
- **Local storage only**: All data stored in `~/Library/Application Support/se.demoskop.clipboard/`
- **No telemetry**: We don't collect any usage data
- **Hardened Runtime**: Enabled for maximum security
- **Sandboxing**: Disabled to allow clipboard access (required functionality)

## Troubleshooting

### App doesn't appear in menu bar
- Check System Settings → Control Center → Menu Bar Only
- Try restarting the app

### Hotkeys not working
- Grant Accessibility permissions in System Settings → Privacy & Security → Accessibility
- Check for conflicts with other apps

### Markdown not converting
- Ensure "Auto-convert Markdown" is enabled in Preferences
- Check if the text contains valid Markdown syntax

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please read CONTRIBUTING.md first.
