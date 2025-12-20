# TestFlight Setup Guide for Lucidity Watch App

This guide will walk you through setting up TestFlight distribution for your Lucidity app.

## Current Project Configuration

- **Bundle ID (Watch App)**: `com.sanzgiri.Lucidity.watchkitapp`
- **Bundle ID (Container)**: `com.sanzgiri.Lucidity`
- **Development Team**: `QWS4287C7U`
- **Platform**: watchOS only (standalone Watch app)

---

## Part 1: Apple Developer Portal Setup (10 minutes)

### Step 1: Create App IDs

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** (Add button)

#### Create Watch App ID:
- **Platform**: watchOS
- **Description**: `Lucidity Watch App`
- **Bundle ID**: `com.sanzgiri.Lucidity.watchkitapp` (Explicit)
- **Capabilities**: Check these:
  - ✅ **HealthKit**
- Click **Continue** → **Register**

#### Create iOS Container App ID:
- **Platform**: iOS
- **Description**: `Lucidity Container`
- **Bundle ID**: `com.sanzgiri.Lucidity` (Explicit)
- **Capabilities**: (None needed for container)
- Click **Continue** → **Register**

### Step 2: Verify Provisioning Profiles (Optional - Xcode handles this)

Xcode will automatically create provisioning profiles when you archive. You can skip manual creation.

---

## Part 2: App Store Connect Setup (5 minutes)

### Step 1: Create App Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in the form:
   - **Platform**: ✅ watchOS (uncheck iOS)
   - **Name**: `Lucidity` (must be unique on App Store)
     - If taken, try: `Lucidity Dream`, `Lucidity Sleep`, `Silent Lucidity`, etc.
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: Select `com.sanzgiri.Lucidity.watchkitapp` (Watch App)
   - **SKU**: `lucidity-watch-001` (your internal identifier)
   - **User Access**: Full Access
4. Click **Create**

### Step 2: Fill Required App Information

You'll need to provide this before you can use TestFlight:

1. **App Information** tab:
   - **Privacy Policy URL**: Can use placeholder like `https://example.com/privacy` for testing
   - **Category**: Primary: Health & Fitness, Secondary: Lifestyle

2. **Pricing and Availability**:
   - Select **Free**
   - Available in all territories

3. **Version Information** (1.0):
   - **Screenshots**: You'll need at least one Watch screenshot
     - Use Watch Simulator: Cmd+S to capture
     - Required sizes: Check App Store Connect for current requirements
   - **Description**:
     ```
     Lucidity helps promote lucid dreaming by detecting REM sleep phases and
     delivering subtle haptic cues to your wrist. Using heart rate monitoring
     and sleep analysis, the app identifies probable REM windows and provides
     gentle feedback to enhance dream awareness.

     Features:
     • REM sleep phase detection using heart rate variability
     • Gentle haptic cues during detected REM periods
     • Overnight workout session for continuous monitoring
     • History log of cue delivery events

     Note: This app is for wellness and entertainment purposes only.
     ```
   - **Keywords**: `lucid dreaming, rem sleep, sleep tracking, dream awareness`
   - **Support URL**: Can use placeholder for testing
   - **Marketing URL**: Optional

**Note**: You don't need to complete everything for TestFlight, but App Store Connect requires some basic info.

---

## Part 3: Xcode Configuration and Archive (15 minutes)

### Step 1: Open Project in Xcode

```bash
cd /Users/sanzgiri/silent_lucidity/Lucidity
open Lucidity.xcodeproj
```

### Step 2: Verify App Icon (Already Added ✅)

1. In Xcode, click `Assets.xcassets` in left sidebar
2. Click `AppIcon`
3. You should see your REM sleep icon (blue circle with moon and ZZZs)
4. ✅ Icon is ready - no action needed!

### Step 3: Configure Signing

1. Select **Lucidity Watch App** target in left sidebar
2. Go to **Signing & Capabilities** tab
3. Verify:
   - ✅ **Automatically manage signing** is checked
   - **Team**: Should show your team (QWS4287C7U)
   - **Bundle Identifier**: `com.sanzgiri.Lucidity.watchkitapp`
4. Repeat for **Lucidity** (container) target if needed

### Step 4: Bump Version Number (First time only)

1. Select **Lucidity Watch App** target
2. Go to **General** tab
3. Verify:
   - **Version**: `1.0`
   - **Build**: `1`

### Step 5: Select "Any watchOS Device"

1. At the top of Xcode, click the device dropdown (next to scheme selector)
2. Select **Any watchOS Device (arm64)**
   - NOT a simulator!
   - This is required for archiving

### Step 6: Archive the App

1. Menu: **Product** → **Archive**
2. Wait for build to complete (2-5 minutes)
3. **Organizer** window will open automatically showing your archive

**If Archive option is greyed out**: Make sure you selected "Any watchOS Device" in Step 4.

---

## Part 4: Upload to App Store Connect (10 minutes)

### From Xcode Organizer:

1. In the **Organizer** window (opens after archiving):
2. Select your archive
3. Click **Distribute App** button
4. Choose **App Store Connect** → **Next**
5. Choose **Upload** → **Next**
6. Distribution options:
   - ✅ **App Thinning**: All compatible device variants
   - ✅ **Rebuild from Bitcode**: Yes (if available)
   - ✅ **Include symbols**: Yes
   - ✅ **Manage Version and Build Number**: Yes (Xcode will auto-increment)
   - Click **Next**
7. **Automatically manage signing** → **Next**
8. Review summary → **Upload**
9. Wait for upload (2-10 minutes depending on connection)

### Verify Upload:

1. You'll see "Upload Successful" when done
2. Go to [App Store Connect](https://appstoreconnect.apple.com)
3. Click your app → **TestFlight** tab
4. Wait 5-15 minutes for Apple to process your build
5. You'll get an email when processing is complete
6. Build will appear under **watchOS** section with status **Ready to Submit** or **Testing**

**Important**: If you get export compliance questions:
- Does your app use encryption? → **No** (uses standard Apple encryption only)

---

## Part 5: Set Up TestFlight Testing (5 minutes)

### Enable TestFlight:

1. In App Store Connect → Your App → **TestFlight** tab
2. Click on your build number under **watchOS**
3. **Test Information**:
   - **What to Test**:
     ```
     Initial build for overnight REM detection testing.
     Test the "Start Night" button before sleep and verify haptic cues.
     ```
   - **Test Details**: Optional
   - Click **Save**

### Add Yourself as Tester:

1. Still in **TestFlight** tab
2. Click **Internal Testing** (left sidebar)
3. Click **+** next to **Internal Group** → **Add Internal Testers**
4. Your Apple ID email should appear → Select it → **Add**
5. Click on the **Build** section → **+** → Select your uploaded build

**Note**: Internal testers (you) are automatically approved. External testers require Apple review.

---

## Part 6: Install on Apple Watch (5 minutes)

### On Your iPhone:

1. **Install TestFlight app** from App Store (if not already installed)
   - Search "TestFlight" → Install

2. **Open TestFlight app**
   - You should see "Lucidity" appear automatically (same Apple ID)
   - If not, check your email for invite link

3. **Accept the Test**:
   - Tap **Lucidity**
   - Tap **Accept** (terms of testing)
   - Tap **Install**

### On Your Apple Watch:

4. **The app auto-installs on paired Watch**:
   - Look for **Lucidity** icon on Watch
   - May take 1-2 minutes to appear
   - Watch should be on charger and near iPhone for faster install

5. **Open on Watch**:
   - Tap the Lucidity icon
   - Grant HealthKit permissions when prompted
   - You're ready to test!

---

## Testing the App

### First Test (Daytime):

1. On Watch, open **Lucidity**
2. Tap **Start Night**
3. Grant HealthKit permissions if prompted
4. App should show "Last heart rate" updating
5. Tap **Stop** to end session

### Overnight Test:

1. Charge Watch to 100% before bed
2. Wear Watch to sleep
3. Open **Lucidity** app
4. Tap **Start Night**
5. Sleep normally
6. Wake up and tap **Stop**
7. Tap **View History** to see cue events

---

## Troubleshooting

### "Build is Processing" for too long (>30 min):
- Check email for rejection notice
- Common issues: Missing compliance info, provisioning profile errors

### "No apps available to test":
- Make sure you're logged into TestFlight with same Apple ID
- Check email for invite link
- Refresh TestFlight app

### App not appearing on Watch:
- Open Watch app on iPhone → My Watch → scroll down
- Find Lucidity → toggle **Show on Apple Watch**
- Make sure Watch is connected and on WiFi

### Archive option greyed out in Xcode:
- Select "Any watchOS Device" (not simulator)
- Clean build folder: Product → Clean Build Folder
- Restart Xcode

### Signing errors:
- Xcode → Preferences → Accounts → Download Manual Profiles
- Select target → Signing & Capabilities → Re-check "Automatically manage"

---

## Updating Your App

When you fix bugs or add features:

1. **Increment build number**:
   - Xcode will auto-increment if "Manage Version" was checked
   - Or manually: General tab → Build: `2`, `3`, etc.

2. **Repeat Part 3-4**:
   - Archive → Upload
   - Wait for processing

3. **TestFlight auto-updates** or testers can manually update

---

## Next Steps After TestFlight Testing

Once you've tested thoroughly:

1. Complete all App Store Connect metadata
2. Add required screenshots (all Watch sizes)
3. Submit for App Review
4. Wait 1-3 days for review
5. App goes live on App Store!

For now, focus on TestFlight testing to verify the app works correctly on your Watch.

---

## Quick Reference Commands

```bash
# Open project
cd /Users/sanzgiri/silent_lucidity/Lucidity
open Lucidity.xcodeproj

# Build for testing (CLI - not for TestFlight)
xcodebuild -project Lucidity.xcodeproj -target "Lucidity Watch App" -sdk watchos build

# Archive must be done through Xcode GUI:
# Product → Archive
```

---

## Important Notes

- **TestFlight builds expire after 90 days** - need to upload new build
- **Up to 100 builds** can be active at once
- **Internal testing**: Up to 100 testers (Apple employees/team)
- **External testing**: Up to 10,000 testers (requires Apple review)
- **Export compliance**: If asked, answer "No" for encryption (standard Apple crypto only)

Good luck! Let me know if you hit any issues during the process.
