# DemoskopClipboard Distribution Guide

This guide covers how to build, sign, notarize, and distribute DemoskopClipboard for macOS.

## Prerequisites

### 1. Apple Developer Program
- Membership in Apple Developer Program ($99/year)
- Access to [developer.apple.com](https://developer.apple.com)

### 2. Certificates
Install the following certificates in your Keychain:
- **Developer ID Application** - For distributing outside the App Store
- **Developer ID Installer** - For creating signed .pkg installers (optional)

To download certificates:
1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)
2. Click "+" to create a new certificate
3. Select "Developer ID Application"
4. Follow the steps to generate and download

### 3. App-Specific Password
Create an app-specific password for notarization:
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in and go to Security → App-Specific Passwords
3. Generate a new password
4. Store it in your Keychain:
   ```bash
   security add-generic-password -s "AC_PASSWORD" -a "your@email.com" -w "xxxx-xxxx-xxxx-xxxx"
   ```

## Build Process

### Step 1: Build Release

```bash
./scripts/build-release.sh
```

This creates:
- `build/DemoskopClipboard.app` - The application bundle
- `build/entitlements.plist` - Entitlements for code signing

### Step 2: Code Sign & Notarize

Edit `scripts/notarize.sh` with your Team ID and Apple ID, then run:

```bash
./scripts/notarize.sh YOUR_TEAM_ID your@email.com
```

Or run the steps manually:

```bash
# Code sign
codesign --force --options runtime \
    --entitlements build/entitlements.plist \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp \
    build/DemoskopClipboard.app

# Verify signature
codesign --verify --deep --strict --verbose=2 build/DemoskopClipboard.app

# Create ZIP for notarization
ditto -c -k --keepParent build/DemoskopClipboard.app build/DemoskopClipboard.zip

# Submit for notarization
xcrun notarytool submit build/DemoskopClipboard.zip \
    --apple-id "your@email.com" \
    --team-id "TEAM_ID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# Staple the ticket
xcrun stapler staple build/DemoskopClipboard.app

# Verify
spctl -a -t exec -vv build/DemoskopClipboard.app
```

### Step 3: Create DMG

```bash
./scripts/create-dmg.sh
```

Then sign and notarize the DMG:

```bash
# Sign DMG
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" build/DemoskopClipboard-1.0.0.dmg

# Notarize DMG
xcrun notarytool submit build/DemoskopClipboard-1.0.0.dmg \
    --apple-id "your@email.com" \
    --team-id "TEAM_ID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# Staple
xcrun stapler staple build/DemoskopClipboard-1.0.0.dmg
```

## Distribution Methods

### Method 1: Direct Download (Website)
1. Host the notarized DMG on your website
2. Users download and drag the app to Applications
3. Gatekeeper will verify the notarization automatically

### Method 2: MDM Deployment (Enterprise)

For Jamf, Mosyle, Kandji, or other MDM solutions:

1. Create a signed installer package:
   ```bash
   pkgbuild --root build/DemoskopClipboard.app \
            --identifier se.demoskop.clipboard \
            --version 1.0.0 \
            --install-location /Applications \
            --sign "Developer ID Installer: Your Name (TEAM_ID)" \
            build/DemoskopClipboard-1.0.0.pkg
   ```

2. Notarize the package:
   ```bash
   xcrun notarytool submit build/DemoskopClipboard-1.0.0.pkg \
       --apple-id "your@email.com" \
       --team-id "TEAM_ID" \
       --password "@keychain:AC_PASSWORD" \
       --wait

   xcrun stapler staple build/DemoskopClipboard-1.0.0.pkg
   ```

3. Upload to your MDM solution

### Method 3: Mac App Store (Optional)

For App Store distribution:
1. Create an App Store Connect record
2. Sign with "Apple Distribution" certificate instead of "Developer ID"
3. Use Transporter or altool to upload
4. Note: App Store apps are sandboxed, which limits clipboard access

## Auto-Updates with Sparkle

DemoskopClipboard includes Sparkle 2 for auto-updates.

### Setup

1. Generate Ed25519 keys:
   ```bash
   ./scripts/generate_keys.sh  # Creates EdDSA key pair
   ```

2. Update `Info.plist`:
   - Set `SUPublicEDKey` to your public key
   - Set `SUFeedURL` to your appcast.xml URL

3. Create `appcast.xml` on your server:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
     <channel>
       <title>DemoskopClipboard Updates</title>
       <item>
         <title>Version 1.0.0</title>
         <pubDate>Wed, 29 Jan 2026 12:00:00 +0000</pubDate>
         <sparkle:version>1</sparkle:version>
         <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
         <enclosure url="https://yoursite.com/DemoskopClipboard-1.0.0.dmg"
                    sparkle:edSignature="YOUR_SIGNATURE"
                    length="12345678"
                    type="application/octet-stream"/>
       </item>
     </channel>
   </rss>
   ```

4. Sign updates with your private key:
   ```bash
   ./scripts/sign_update.sh DemoskopClipboard-1.0.0.dmg
   ```

## Configuration for Your Company

### 1. Update Bundle Identifier
In `ClipboardManager/Info.plist` and the Xcode project:
- Change `se.demoskop.clipboard` to your company's identifier

### 2. Update Copyright
In `ClipboardManager/Info.plist`:
- Update `NSHumanReadableCopyright`

### 3. Update Sparkle URLs
In `ClipboardManager/Info.plist`:
- Set `SUFeedURL` to your appcast.xml location
- Set `SUPublicEDKey` to your public key

### 4. Add App Icon
Create an `AppIcon.icns` file and add it to the project resources.

## Troubleshooting

### "App is damaged and can't be opened"
- App wasn't properly notarized
- Re-run notarization and stapling

### "Developer cannot be verified"
- Check that Developer ID certificate is valid
- Verify code signature: `codesign -dv --verbose=4 DemoskopClipboard.app`

### Notarization Fails
- Check Apple's notarization log:
  ```bash
  xcrun notarytool log [submission-id] \
      --apple-id "your@email.com" \
      --team-id "TEAM_ID" \
      --password "@keychain:AC_PASSWORD"
  ```

### Sparkle Updates Not Working
- Verify appcast.xml is accessible
- Check public key matches private key used for signing
- Test with `defaults write se.demoskop.clipboard SUEnableAutomaticChecks -bool YES`

## Security Considerations

### Entitlements
The app uses these entitlements (`ClipboardManager/ClipboardManager.entitlements`):
- `com.apple.security.app-sandbox`: **false** (required for clipboard access)
- `com.apple.security.hardened-runtime`: **true** (required for notarization)
- `com.apple.security.automation.apple-events`: **true** (for paste simulation)

### Privacy
- No network access except for Sparkle updates
- All data stored locally in `~/Library/Application Support/se.demoskop.clipboard/`
- No telemetry or data collection

### Accessibility Permission
The app requires Accessibility permission for paste simulation via CGEvent.
Users are prompted on first launch.

## Support

For issues with the distribution process, check:
- Apple Developer Forums
- Sparkle GitHub Issues
- This project's GitHub Issues
