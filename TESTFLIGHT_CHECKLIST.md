# TestFlight Upload Checklist

Use this quick checklist to upload your app to TestFlight.

## ✅ IMPORTANT: App Icon Added

**Current Status**: ✅ **App icon is SET**

Icon successfully created from your SVG and added to the project at 1024x1024px PNG.

Your icon features a blue circle background with moon, ZZZs, vibration waves, and "REM ALERT" text - perfect for a sleep tracking app!

---

## Pre-Upload Checklist

### ☑️ Development Environment
- [ ] Enrolled in Apple Developer Program ($99/year)
- [ ] Xcode installed and updated
- [ ] Logged into Xcode with Apple ID (Xcode → Settings → Accounts)
- [ ] Project opens without errors

### ☑️ Project Configuration
- [x] **App Icon added** (1024x1024px PNG) ✅ Already added
- [ ] Bundle ID: `com.sanzgiri.Lucidity.watchkitapp`
- [ ] Development Team: Set to your team ID
- [ ] Signing: "Automatically manage signing" enabled
- [ ] Version: 1.0, Build: 1

### ☑️ Apple Developer Portal
- [ ] Created App ID: `com.sanzgiri.Lucidity.watchkitapp` (watchOS)
- [ ] Created App ID: `com.sanzgiri.Lucidity` (iOS container)
- [ ] Enabled HealthKit capability on Watch App ID

### ☑️ App Store Connect
- [ ] Created app record
- [ ] Chose unique app name (e.g., "Lucidity Dream" if "Lucidity" is taken)
- [ ] Set Privacy Policy URL (can be placeholder)
- [ ] Selected category (Health & Fitness)

---

## Upload Process

### Step 1: Open Project
```bash
cd /Users/sanzgiri/silent_lucidity/Lucidity
open Lucidity.xcodeproj
```

### Step 2: Select Device
- Top of Xcode: Click device dropdown
- Select: **Any watchOS Device (arm64)**
- ❌ NOT a simulator!

### Step 3: Archive
- Menu: **Product** → **Archive**
- Wait 2-5 minutes
- Organizer window opens automatically

### Step 4: Distribute
1. Click **Distribute App**
2. Choose **App Store Connect**
3. Choose **Upload**
4. Accept default options
5. **Upload** (wait 2-10 min)

### Step 5: Wait for Processing
- Check email (Apple sends confirmation)
- Usually 5-15 minutes
- Go to App Store Connect → TestFlight
- Build appears under "watchOS" section

### Step 6: Enable for Testing
1. Click your build number
2. Fill "What to Test" field
3. Click Internal Testing → Add yourself as tester
4. Select the build

---

## Installation on Watch

### On iPhone:
1. Download **TestFlight** app from App Store
2. Open TestFlight
3. Tap **Lucidity** (appears automatically)
4. Tap **Install**

### On Apple Watch:
- App auto-installs to Watch (paired device)
- Look for Lucidity icon on Watch
- May take 1-2 minutes

---

## Quick Test

1. Open Lucidity on Watch
2. Tap "Start Night"
3. Grant HealthKit permissions
4. Verify heart rate shows up
5. Tap "Stop"
6. ✅ Success!

---

## Common Issues

| Problem | Solution |
|---------|----------|
| Archive greyed out | Select "Any watchOS Device" not simulator |
| No app in TestFlight | Check email for invite, same Apple ID? |
| App not on Watch | iPhone Watch app → Lucidity → Show on Watch |
| Upload failed | Check email for reason, often icon/compliance |
| Build processing >30min | Likely failed, check email |

---

## Version Updates

To upload new version after code changes:

1. Increment build number (auto or manual)
2. Archive again (Product → Archive)
3. Upload to App Store Connect
4. TestFlight auto-updates or manual update

Build number must always increase: 1, 2, 3, etc.

---

## Files Created for Reference

- `TESTFLIGHT_SETUP.md` - Detailed step-by-step guide (read this first)
- `TESTFLIGHT_CHECKLIST.md` - This quick checklist
- `BUILD_FIXES.md` - Build issues and solutions

---

## Time Estimates

- Developer Portal setup: 10 min
- App Store Connect setup: 5 min
- Xcode archive & upload: 15 min
- Apple processing: 15 min
- TestFlight install: 5 min
- **Total: ~50 minutes first time**

Subsequent uploads: ~20 minutes

---

## Need Help?

See the detailed `TESTFLIGHT_SETUP.md` guide for:
- Screenshots of each step
- Troubleshooting details
- App Store metadata requirements
- Export compliance info

Good luck! 🚀
