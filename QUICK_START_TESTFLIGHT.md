# Quick Start: TestFlight in 6 Steps

## ✅ App Icon Already Added

Your app icon has been created and is ready to go! You can verify it in Xcode:
- Open project → `Assets.xcassets` → `AppIcon` ✅

---

## 1️⃣ Developer Portal (5 min)

**URL**: https://developer.apple.com/account

1. **Identifiers** → **+** → Create two App IDs:
   - watchOS: `com.sanzgiri.Lucidity.watchkitapp` + HealthKit ✅
   - iOS: `com.sanzgiri.Lucidity`

---

## 2️⃣ App Store Connect (5 min)

**URL**: https://appstoreconnect.apple.com

1. **My Apps** → **+** → **New App**
2. Platform: ✅ watchOS only
3. Name: `Lucidity` (or variant if taken)
4. Bundle ID: `com.sanzgiri.Lucidity.watchkitapp`
5. SKU: `lucidity-watch-001`

**Quick metadata** (required minimum):
- Category: Health & Fitness
- Privacy URL: `https://example.com/privacy` (placeholder OK)
- Price: Free

---

## 3️⃣ Archive in Xcode (5 min)

```bash
cd /Users/sanzgiri/silent_lucidity/Lucidity
open Lucidity.xcodeproj
```

1. Device dropdown → **Any watchOS Device (arm64)** ⚠️ Not simulator!
2. **Product** → **Archive**
3. Wait for Organizer window

---

## 4️⃣ Upload (10 min)

**In Organizer:**
1. **Distribute App**
2. **App Store Connect** → **Upload**
3. Accept defaults → **Upload**
4. Wait for "Upload Successful"

---

## 5️⃣ Enable TestFlight (2 min)

**App Store Connect** → Your App → **TestFlight**:
1. Wait for email "Build is ready" (~15 min)
2. Click build number
3. Fill "What to Test"
4. **Internal Testing** → Add yourself
5. Select build

---

## 6️⃣ Install on Watch (2 min)

**iPhone:**
1. Download **TestFlight** app
2. Open → Tap **Lucidity**
3. **Install**

**Watch:**
- Auto-installs (wait 1-2 min)
- Open Lucidity
- Grant HealthKit permissions
- Tap "Start Night" → Test! ✅

---

## Troubleshooting One-Liners

| Issue | Fix |
|-------|-----|
| Archive greyed out | Select "Any watchOS Device" |
| Upload failed | Check email for specific error |
| No app in TestFlight | Same Apple ID? Check email |
| App not on Watch | iPhone: Watch app → Lucidity → Show on Watch |

---

## Update Process

Code change → Increment build # → Archive → Upload → Auto-updates in TestFlight

---

## 📚 Full Guides

- **TESTFLIGHT_SETUP.md** - Detailed walkthrough with screenshots
- **TESTFLIGHT_CHECKLIST.md** - Pre-flight checklist
- **BUILD_FIXES.md** - Build troubleshooting

---

**Total Time**: ~40 minutes first upload, ~15 minutes for updates

**Need more detail?** Read `TESTFLIGHT_SETUP.md`
